// 液态玻璃折射着色器
//
// 移植自 wekit 的 Lens.kt（AGSL），原始来源 Kyant0/AndroidLiquidGlass (Apache-2.0)。
// 与原版的区别：
//   - AGSL 的 content.eval() 采样的是"当前图层已渲染内容"，Flutter 这边没有等价物，
//     所以背景图由 Dart 侧用 RepaintBoundary.toImageSync() 抓好，通过 uBackdrop 传进来。
//   - 只渲染圆角矩形的"边缘带"（宽度 uRefractionHeight），内部直接输出全透明，
//     让下层的 BackdropFilter 模糊原样透出。这样一次 draw 只负责折射，职责干净。
//
// 输出为预乘 alpha。

#include <flutter/runtime_effect.glsl>

precision highp float;

// 注意：uniform 声明顺序决定 setFloat 的下标，改动顺序必须同步改 Dart 侧。
uniform vec2 uSize;             // 被绘制矩形的尺寸（逻辑像素 * devicePixelRatio 前的本地坐标）
uniform vec2 uBackdropSize;     // uBackdrop 的实际像素尺寸
uniform vec2 uBarOrigin;        // 本矩形左上角在 uBackdrop 坐标系中的位置
uniform float uRadius;          // 圆角半径
uniform float uRefractionHeight; // 边缘带宽度：越大，"玻璃越厚"
uniform float uRefractionAmount; // 采样偏移量：越大，边缘扭曲越强
uniform float uDepthEffect;      // >0 时把法线往中心方向偏，产生球面凸起感
uniform float uChromaticAberration; // 色散强度，0 关闭
uniform float uAlpha;           // 整体强度，用于淡入淡出

uniform sampler2D uBackdrop;

out vec4 fragColor;

/// length 为 0 时 normalize 会出 NaN，在角点上会闪黑点，必须挡掉。
vec2 safeNormalize(vec2 v) {
    float len = length(v);
    return len > 1e-5 ? v / len : vec2(0.0);
}

/// 圆角矩形有符号距离场：内部为负，外部为正，边界为 0。
float sdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    float outside = length(max(cornerCoord, vec2(0.0))) - radius;
    float inside = min(max(cornerCoord.x, cornerCoord.y), 0.0);
    return outside + inside;
}

/// 距离场梯度，即边界的外法线方向。折射就是沿着它偏移采样点。
vec2 gradSdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    if (cornerCoord.x >= 0.0 || cornerCoord.y >= 0.0) {
        // 圆角区域：法线指向角心外侧
        return sign(coord) * safeNormalize(max(cornerCoord, vec2(0.0)));
    }
    // 直边区域：取更接近的那条边的法线
    float gradX = step(cornerCoord.y, cornerCoord.x);
    return sign(coord) * vec2(gradX, 1.0 - gradX);
}

/// 把线性深度映射成圆弧，让偏移量在最外沿急剧增大 —— 真玻璃的边缘就是这个手感。
float circleMap(float x) {
    return 1.0 - sqrt(1.0 - x * x);
}

vec3 sampleBackdrop(vec2 localCoord) {
    vec2 uv = (uBarOrigin + localCoord) / uBackdropSize;
    return texture(uBackdrop, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

void main() {
    vec2 coord = FlutterFragCoord().xy;
    vec2 halfSize = uSize * 0.5;
    vec2 centered = coord - halfSize;

    float sd = sdRoundedRect(centered, halfSize, uRadius);

    // 形状外：交给 ClipRRect 处理，这里直接透明
    if (sd > 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    // 边缘带以内：不碰，让下层模糊透出
    if (-sd >= uRefractionHeight) {
        fragColor = vec4(0.0);
        return;
    }

    // 0 = 边缘带内沿，1 = 最外沿
    float depth = 1.0 - (-sd / uRefractionHeight);
    float offset = circleMap(depth) * uRefractionAmount;

    float gradRadius = min(uRadius * 1.5, min(halfSize.x, halfSize.y));
    vec2 grad = safeNormalize(
        gradSdRoundedRect(centered, halfSize, gradRadius)
        + uDepthEffect * safeNormalize(centered)
    );

    // 沿法线向外偏移采样点：边缘于是显示出"本该在形状外面"的内容，即折射
    vec2 refracted = coord + offset * grad;

    vec3 rgb;
    if (uChromaticAberration > 0.0) {
        // 色散强度随离中心的距离增大，所以彩虹只出现在角上，不会糊满整条边
        float k = uChromaticAberration
            * ((centered.x * centered.y) / (halfSize.x * halfSize.y));
        vec2 disp = offset * grad * k;
        rgb = vec3(
            sampleBackdrop(refracted + disp).r,
            sampleBackdrop(refracted).g,
            sampleBackdrop(refracted - disp).b
        );
    } else {
        rgb = sampleBackdrop(refracted);
    }

    // 往内沿淡出，避免和下层模糊之间出现硬边
    float alpha = depth * uAlpha;
    fragColor = vec4(rgb * alpha, alpha);
}
