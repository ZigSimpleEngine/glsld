#version 460
#pragma shader_stage(compute)
#extension GL_EXT_shader_explicit_arithmetic_types : enable

// ============================================================================
// C++ 风格 const auto + using 混合类型推导测试
// 规则：
//   1) 所有测试变量统一使用 const auto；
//   2) 所有显式构造函数调用统一通过 using 别名调用；
//   3) 结构体构造同样使用 Alias 名称；
//   4) 数组构造器使用数组类型别名，避免直接出现 T[] / T[N] 构造调用。
// ============================================================================
using float2        = vec2;
using float3        = vec3;
using float4        = vec4;
using int2          = ivec2;
using int3          = ivec3;
using int4          = ivec4;
using uint2         = uvec2;
using uint3         = uvec3;
using uint4         = uvec4;
using bool2         = bvec2;
using bool3         = bvec3;
using bool4         = bvec4;
using float2x2      = mat2;
using float2x3      = mat2x3;
using float3x3      = mat3;
using float4x4      = mat4;
using double2       = dvec2;
using double3       = dvec3;
using double4       = dvec4;
using half          = float16_t;
using half2         = f16vec2;
using half3         = f16vec3;
using half4         = f16vec4;
using short         = int16_t;
using short2        = i16vec2;
using short3        = i16vec3;
using short4        = i16vec4;
using long          = int64_t;
using long2         = i64vec2;
using long3         = i64vec3;
using long4         = i64vec4;
using int32         = int32_t;
using uint32        = uint32_t;
using Float         = float;
using Double        = double;
using Int           = int;
using UInt          = uint;
using Bool          = bool;
using float2DArray  = float[2][3];
using float3DArray  = float[2][2][3];

// 常用数组构造别名
using intArray      = int[3];
using intArray2     = int[2];
using intArray4     = int[4];
using intArray2D    = int[2][3];
using floatArray3   = float[3];
using floatArray4   = float[4];
using float2Array   = float2[2];
using float2Array2D = float2[2][2];
using float2Array3D = float2[2][2][2];
using float3Array2  = float3[2];
using float3Array3  = float3[3];
using float4Array2  = float4[2];
using float4Array3  = float4[3];
using float2x2Array = float2x2[2];
using float2x3Array = float2x3[2];

// ============================================================================
// 1. 角度与三角函数 (Section 8.1)
// ============================================================================
// [合法求值]
const auto kRadiansVal      = radians(180.0);                    // 期望: ~3.14159265
const auto kDegreesVal      = degrees(float2(kRadiansVal, 0.0)); // 期望: float2(180.0, 0.0)
const auto kSinVal          = sin(0.0);                          // 期望: 0.0
const auto kCosVal          = cos(float3(0.0));                  // 期望: float3(1.0, 1.0, 1.0)
const auto kTanVal          = tan(0.0);                          // 期望: 0.0
const auto kAsinVal         = asin(1.0);                         // 期望: ~1.5707963 (PI/2)
const auto kAcosVal         = acos(1.0);                         // 期望: 0.0
const auto kAtan1Val        = atan(1.0);                         // 期望: ~0.78539816 (PI/4)
const auto kAtan2Val        = atan(float2(1.0, 0.0), float2(1.0, 1.0)); // 期望: float2(PI/4, 0.0)
const auto kSinhVal         = sinh(0.0);                         // 期望: 0.0
const auto kCoshVal         = cosh(0.0);                         // 期望: 1.0
const auto kTanhVal         = tanh(0.0);                         // 期望: 0.0
const auto kAsinhVal        = asinh(0.0);                        // 期望: 0.0
const auto kAcoshVal        = acosh(1.0);                        // 期望: 0.0
const auto kAtanhVal        = atanh(0.0);                        // 期望: 0.0

// [不合法 / 越界 (应安全产生 NaN/Inf，不崩溃)]
const auto kAsinInvalid     = asin(2.0);                         // 期望: NaN
const auto kAcosInvalid     = acos(-2.0);                        // 期望: NaN
const auto kAcoshInvalid    = acosh(0.5);                        // 期望: NaN
const auto kAtanhInf        = atanh(1.0);                        // 期望: Inf
const auto kAtanhInvalid    = atanh(2.0);                        // 期望: NaN

// ============================================================================
// 2. 指数与对数函数 (Section 8.2)
// ============================================================================
// [合法求值]
const auto kPowVal          = pow(2.0, 8.0);                    // 期望: 256.0
const auto kExpVal          = exp(float2(0.0, 1.0));            // 期望: float2(1.0, 2.7182818)
const auto kExp2Val         = exp2(4.0);                        // 期望: 16.0
const auto kLogVal          = log(2.718281828);                 // 期望: ~1.0
const auto kLog2Val         = log2(float3(2.0, 4.0, 8.0));      // 期望: float3(1.0, 2.0, 3.0)
const auto kSqrtVal         = sqrt(100.0);                      // 期望: 10.0
const auto kInvSqrtVal      = inversesqrt(16.0);                // 期望: 0.25

// [不合法 / 越界]
const auto kSqrtNeg         = sqrt(-4.0);                       // 期望: NaN
const auto kLogZero         = log(0.0);                         // 期望: -Inf
const auto kLogNeg          = log(-1.0);                        // 期望: NaN
const auto kPowInvalid      = pow(-2.0, 0.5);                   // 期望: NaN
const auto kInvSqrtZero     = inversesqrt(0.0);                 // 期望: Inf

// ============================================================================
// 3. 通用函数 (Section 8.3)
// ============================================================================
// [合法求值 - 标量与向量重载]
const auto kAbsInt          = abs(-50);                         // 期望: 50
const auto kAbsIvec         = abs(int2(10u, 20u));              // 期望: uint2(10u, 20u)
const auto kSignFloat       = sign(-3.5);                       // 期望: -1.0
const auto kSignIvec        = sign(int3(-10, 0, 10));           // 期望: int3(-1, 0, 1)
const auto kSignVec         = sign(float2(0.0, 5.0));           // 期望: float2(0.0, 1.0)
const auto kFloorVal        = floor(float2(1.9, -1.1));         // 期望: float2(1.0, -2.0)
const auto kTruncVal        = trunc(float2(1.9, -1.1));         // 期望: float2(1.0, -1.0)
const auto kRoundEvenVal    = roundEven(2.5);                   // 期望: 2.0 (银行家舍入)
const auto kCeilVal         = ceil(4.1);                        // 期望: 5.0
const auto kFractVal        = fract(5.75);                      // 期望: 0.75
const auto kModGlsl         = mod(-5.0, 3.0);                   // 期望: 1.0
const auto kMinInt          = min(-10, 20);                     // 期望: -10
const auto kMaxUint         = max(uint2(10u, 100u), uint2(50u, 5u)); // 期望: uint2(50u, 100u)
const auto kClampVal        = clamp(15.0, 0.0, 10.0);           // 期望: 10.0
const auto kMixFloat        = mix(float2(0.0), float2(10.0), 0.5);   // 期望: float2(5.0, 5.0)
const auto kMixVecFactor    = mix(float2(0.0), float2(10.0), float2(0.2, 0.8));  // 期望: float2(2.0, 8.0)
const auto kMixBoolIvec     = mix(int2(1, 2), int2(10, 20), bool2(true, false)); // 期望: int2(10, 2)
const auto kStepVal         = step(5.0, 7.0);                   // 期望: 1.0
const auto kSmoothstepVal   = smoothstep(0.0, 1.0, 0.5);        // 期望: 0.5
const auto kFmaVal          = fma(2.0, 3.0, 4.0);               // 期望: 10.0
const auto kLdexpVal        = ldexp(1.5, 3);                    // 期望: 12.0 (1.5 * 2^3)

// [浮点特征判断]
const auto kIsNanTrue       = isnan(kSqrtNeg);                  // 期望: true
const auto kIsNanFalse      = isnan(1.0);                       // 期望: false
const auto kIsInfTrue       = isinf(kLogZero);                  // 期望: true

// [基础 32 位重解释]
const auto kFloatBits       = floatBitsToInt(1.0);              // 期望: 0x3F800000 (1065353216)
const auto kIntBits         = intBitsToFloat(0x3F800000);       // 期望: 1.0

// [GL_EXT 显式位宽位重解释]
const auto kHalfBits        = halfBitsToInt16(1.0hf);            // 期望: 0x3C00 (15360)
const auto kInt16ToHalf     = int16BitsToHalf(short(0x3C00));    // 期望: 1.0
const auto kDoubleBits      = doubleBitsToInt64(1.0);            // 期望: 0x3FF0000000000000 (4607182418800017408)
const auto kInt64ToDouble   = int64BitsToDouble(kDoubleBits);    // 期望: 1.0

// ============================================================================
// 4. 打包与解包函数 (Section 8.4 及 EXT 扩展)
// ============================================================================
// [GLSL 4.60 核心打包/解包]
const auto kPackUnorm2x16    = packUnorm2x16(float2(0.0, 1.0));          // 期望: 0xFFFF0000u (4294901760)
const auto kUnpackUnorm2x16  = unpackUnorm2x16(kPackUnorm2x16);          // 期望: float2(0.0, 1.0)
const auto kPackHalf2x16     = packHalf2x16(float2(1.0, 2.0));           // 期望: 0x40003C00u (1074266112)
const auto kUnpackHalf2x16   = unpackHalf2x16(kPackHalf2x16);            // 期望: float2(1.0, 2.0)
const auto kPackUnorm4x8     = packUnorm4x8(float4(1.0, 0.0, 0.0, 1.0)); // 期望: 0xFF0000FFu (4278190335)
const auto kUnpackUnorm4x8   = unpackUnorm4x8(kPackUnorm4x8);            // 期望: float4(1.0, 0.0, 0.0, 1.0)
const auto kPackDouble2x32   = packDouble2x32(uint2(0, 0x3FF00000u));    // 期望: 1.0
const auto kUnpackDouble2x32 = unpackDouble2x32(kPackDouble2x32);        // 期望: uint2(0, 1072693248u)

// [GL_EXT 扩展整数/半精度打包]
const auto kPackFloat2x16    = packFloat2x16(half2(1.0, 2.0));  // 期望: 0x40003C00u (1074266112)
const auto kUnpackFloat2x16  = unpackFloat2x16(kPackFloat2x16); // 期望: half2(1.0, 2.0)
const auto kPackInt2x16      = packInt2x16(short2(-1, 1));      // 期望: 0x0001FFFF (131071)
const auto kUnpackInt2x16    = unpackInt2x16(kPackInt2x16);     // 期望: short2(-1, 1)
const auto kPackInt2x32      = packInt2x32(int2(-1, 1));        // 期望: 0x00000001FFFFFFFF (8589934591)
const auto kUnpackInt2x32    = unpackInt2x32(kPackInt2x32);     // 期望: int2(-1, 1)

// ============================================================================
// 5. 几何函数 (Section 8.5)
// ============================================================================
const auto kLengthVal      = length(float3(0.0, 3.0, 4.0));                                           // 期望: 5.0
const auto kDistanceVal    = distance(float2(1.0, 2.0), float2(4.0, 6.0));                            // 期望: 5.0
const auto kDotVal         = dot(float3(1.0, 2.0, 3.0), float3(4.0, 5.0, 6.0));                       // 期望: 32.0
const auto kCrossVal       = cross(float3(1.0, 0.0, 0.0), float3(0.0, 1.0, 0.0));                     // 期望: float3(0.0, 0.0, 1.0)
const auto kNormalizeVal   = normalize(float2(0.0, 5.0));                                             // 期望: float2(0.0, 1.0)
const auto kFaceForwardVal = faceforward(float3(1.0), float3(0.0, 0.0, 1.0), float3(0.0, 0.0, -1.0)); // 期望: float3(1.0)
const auto kReflectVal     = reflect(float2(1.0, -1.0), float2(0.0, 1.0));                            // 期望: float2(1.0, 1.0)
const auto kRefractVal     = refract(float2(0.0, 1.0), float2(0.0, -1.0), 1.0);                       // 期望: float2(0.0, 1.0)

// ============================================================================
// 6. 矩阵操作函数 (Section 8.6)
// ============================================================================
const auto kMatA           = float2x2(1.0, 2.0, 3.0, 4.0);
const auto kMatB           = float2x2(2.0, 0.0, 1.0, 2.0);
const auto kMatCompMult    = matrixCompMult(kMatA, kMatB);     // 期望: float2x2(2.0, 0.0, 3.0, 8.0)
const auto kTransposeMat   = transpose(kMatA);                 // 期望: float2x2(1.0, 3.0, 2.0, 4.0)
const auto kDeterminantVal = determinant(kMatA);               // 期望: -2.0 (1*4 - 2*3)
const auto kInverseMat     = inverse(kMatA);                   // 期望: float2x2(-2.0, 1.0, 1.5, -0.5)
const auto kOuterProd      = outerProduct(float3(1.0, 2.0, 3.0), float2(4.0, 5.0)); // 期望: 2列3行矩阵

// [矩阵与 Swizzle 组合]
const auto kMatrixSwizzleSource  = float4(1.0, 2.0, 3.0, 4.0);
const auto kMatrixFromSwizzles   = float2x2(
    kMatrixSwizzleSource.yx,
    kMatrixSwizzleSource.wz
); // 期望: float2x2(2.0, 1.0, 4.0, 3.0)

const auto kMatrixTimesSwizzle = (kMatrixFromSwizzles * kMatrixSwizzleSource.zx).yx; // 乘法结果 (10,6) 重排后期望: float2(6.0, 10.0)
const auto kSwizzleTimesMatrix = (kMatrixSwizzleSource.xz * kMatrixFromSwizzles).yx; // 乘法结果 (5,13) 重排后期望: float2(13.0, 5.0)

const auto kMatrixOuterFromSwizzles = outerProduct(kMatrixSwizzleSource.wzy, kMatrixSwizzleSource.yx); // 期望: float2x3(8,6,4, 4,3,2)

// 矩阵不能直接 Swizzle；先索引取出列向量后再 Swizzle
const auto kMatrixColumnSwizzle    = kMatrixOuterFromSwizzles[1].zy;            // 第1列 (4,3,2) => float2(2.0, 3.0)
const auto kTransposeColumnSwizzle = transpose(kMatrixOuterFromSwizzles)[2].yx; // 第2列 (4,2)   => float2(2.0, 4.0)

const auto kMatrix = float2x2(2.0, 4.0, 6.0, 8.0);
const auto kZero   = float2x2(0.0);
const auto kResult = kMatrix / kZero;

// ============================================================================
// 7. 向量关系判断函数 (Section 8.7)
// ============================================================================
const auto kLessThanVal = lessThan(float3(1.0, 5.0, 3.0), float3(2.0, 4.0, 3.0)); // 期望: bool3(true, false, false)
const auto kEqualVal    = equal(uint2(5u, 10u), uint2(5u, 20u));                  // 期望: bool2(true, false)
const auto kAnyVal      = any(kLessThanVal);                                      // 期望: true
const auto kAllVal      = all(kLessThanVal);                                      // 期望: false
const auto kNotVal      = not(bool2(true, false));                                // 期望: bool2(false, true)

// ============================================================================
// 8. 整数位级操作函数 (Section 8.8 - 重点验证 32 位截断)
// ============================================================================
const auto kBitCountPos   = bitCount(0x00FF00FF);                // 期望: 16
const auto kBitCountNeg   = bitCount(-1);                        // 期望: 32 (32位全1)
const auto kFindLSBVal    = findLSB(0x00000080);                 // 期望: 7
const auto kFindLSBZero   = findLSB(0);                          // 期望: -1
const auto kFindMSBPos    = findMSB(0x00000080);                 // 期望: 7
const auto kFindMSBZero   = findMSB(0);                          // 期望: -1
const auto kFindMSBNeg    = findMSB(-1);                         // 期望: -1
const auto kBitReverseVal = bitfieldReverse(0x80000000u);        // 期望: 1u (0x00000001u)
const auto kExtractVal    = bitfieldExtract(0x1234u, 4, 4);      // 期望: 3u (提取0x3)
const auto kInsertVal     = bitfieldInsert(0x0000u, 0xAu, 4, 4); // 期望: 0x00A0u (160u)

// ============================================================================
// 9. 向量 Swizzle
// ============================================================================
const auto kSwizzleSource  = float4(1.0, 2.0, 3.0, 4.0);

// [单分量、重排与重复分量]
const auto kSwizzleScalar   = kSwizzleSource.z;                // 期望: 3.0
const auto kSwizzleReorder  = kSwizzleSource.yx;               // 期望: float2(2.0, 1.0)
const auto kSwizzleRepeat   = kSwizzleSource.wwxx;             // 期望: float4(4.0, 4.0, 1.0, 1.0)

// [xyzw / rgba / stpq 三套命名]
const auto kSwizzlePosition = kSwizzleSource.zyx;              // 期望: float3(3.0, 2.0, 1.0)
const auto kSwizzleColor    = kSwizzleSource.bgra;             // 期望: float4(3.0, 2.0, 1.0, 4.0)
const auto kSwizzleTexture  = kSwizzleSource.qpts;             // 期望: float4(4.0, 3.0, 2.0, 1.0)

// [整数、无符号整数与布尔向量]
const auto kSwizzleInt   = int4(-1, 2, -3, 4).wzx;             // 期望: int3(4, -3, -1)
const auto kSwizzleUint  = uint3(10u, 20u, 30u).zx;            // 期望: uint2(30u, 10u)
const auto kSwizzleBool  = bool2(true, false).xyyx;            // 期望: bool4(true, false, false, true)

// [链式 Swizzle 与表达式结果 Swizzle]
const auto kSwizzleChain = kSwizzleSource.wzy.yx;               // wzy = (4,3,2), yx = (3,4)
const auto kSwizzleExpr  = max(kSwizzleSource, float4(2.0)).wz; // 期望: float2(4.0, 3.0)

// [复杂混合复合调用]
const auto kSwizzleComplexConstruct = float4(
    kSwizzleSource.wy,
    max(kSwizzleSource.zx, float2(2.5))
).zwyx; // 期望: float4(3.0, 2.5, 2.0, 4.0)

const auto kSwizzleComplexBuiltins = mix(
    abs(float4(-1.0, -2.0, 3.0, -4.0)).wzyx,
    max(kSwizzleSource, float4(2.0)).xyzw,
    bool4(true, false, true, false)
).bgra; // 期望: float4(3.0, 3.0, 2.0, 1.0)

const auto kSwizzleComplexArithmetic = (
    pow(kSwizzleSource.wzyx, float4(2.0)) + float4(1.0)
).zwxy; // 期望: float4(5.0, 2.0, 17.0, 10.0)

const auto kSwizzleComplexBits = bitCount(
    int4(-1, 0x000000F0, 0x0000FF00, 1).wzyx
).yxwz; // 期望: int4(8, 1, 32, 4)

const auto kSwizzleComplexRelation = not(
    lessThan(kSwizzleSource.wzyx, float4(3.0)).yxwz
).zxyw; // 期望: bool4(false, true, true, false)

const auto kSwizzleComplexScalar = sqrt(pow(
    max(kSwizzleSource.wzy.x, kSwizzleSource.yx.y),
    2.0
)); // 期望: 4.0

// [Swizzle 直接作为函数参数]
const auto kSwizzleArgUnary = length(kSwizzleSource.wzy);       // 期望: sqrt(29.0)
const auto kSwizzleArgBinary = dot(
    kSwizzleSource.wzy,
    kSwizzleSource.xyz
); // 期望: 16.0

const auto kSwizzleArgTernary = clamp(
    kSwizzleSource.wz,
    kSwizzleSource.xy,
    kSwizzleSource.zw
); // 期望: float2(3.0, 3.0)

const auto kSwizzleArgAllSwizzled = mix(
    kSwizzleSource.wzyx,
    kSwizzleSource.xxyy,
    bool4(true, false, false, true).wzyx
); // 期望: float4(1.0, 3.0, 2.0, 2.0)

const auto kSwizzleArgScalarized = pow(
    kSwizzleSource.w,
    kSwizzleSource.x
); // 期望: 4.0

const auto kSwizzleArgNested = max(
    abs(float4(-1.0, -2.0, -3.0, -4.0).wzy),
    min(kSwizzleSource.zyx, float3(2.5))
); // 期望: float3(4.0, 3.0, 2.0)

// ============================================================================
// 10. 数组维度综合验证 (验证 AST 折叠连通性)
// ============================================================================
float array_dim_test[
    Int(kDeterminantVal + 4.0) + // -2.0 + 4.0 = 2
    (Int)kLengthVal +            // 5
    Int(kInvSqrtVal * 4.0) +     // 1
    kBitCountPos                 // 16
];                               // 总大小: 2 + 5 + 1 + 16 = 24

const auto kFinalArraySize = array_dim_test.length(); // 期望: 24

// ============================================================================
// 11. const 数组构造、索引与复合求值
// ============================================================================
// [初始化列表与数组整体 Hover]
using ConstInt = const int;
ConstInt   kScalarArray[4] = { 10, 20, 30, 40 };               // 期望: intArray4(10, 20, 30, 40)
const auto kScalarArrayElement = kScalarArray[2];              // 期望: 30
const auto kScalarArrayComputedIndex  = kScalarArray[bitCount(3) - 1]; // bitCount(3)=2，期望: 20

// [显式尺寸与推导尺寸数组构造器]
const auto kExplicitArray[3] = intArray(7, 8, 9);              // 期望: intArray(7, 8, 9)
const auto kExplicitArrayElement = kExplicitArray[2];          // 期望: 9
const auto kDeducedArray[] = intArray4(11, 22, 33, 44);        // 期望: intArray4(11, 22, 33, 44)
const auto kDeducedArrayLength = kDeducedArray.length();       // 期望: 4

// [元素隐式转换]
using ConstFloat = const Float;
ConstFloat kConvertedArray[3]     = { 1, 2, 3 };               // 期望: floatArray3(1.0, 2.0, 3.0)
const auto kConvertedArrayElement = kConvertedArray[1];        // 期望: 2.0

// [向量数组、索引后 Swizzle 与函数参数]
using ConstFloat4 = const float4;
ConstFloat4 kVectorArray[2] = {
    float4(1.0, 2.0, 3.0, 4.0),
    float4(5.0, 6.0, 7.0, 8.0)
};
const auto kVectorArraySwizzle = kVectorArray[1].wz;           // 期望: float2(8.0, 7.0)
const auto kVectorArrayDot = dot(
    kVectorArray[0].xyz,
    kVectorArray[1].zyx
); // 期望: 34.0
const auto kVectorArrayNestedCall = max(
    abs(kVectorArray[0].wzy - float3(5.0)),
    kVectorArray[1].xyz.yzx
); // max((1,2,3),(6,7,5)) => float3(6.0, 7.0, 5.0)

// [矩阵数组、数组索引 + 矩阵列索引 + Swizzle]
using ConstFloat2x2 = const float2x2;
ConstFloat2x2 kMatrixArray[2]  = {
    float2x2(1.0, 2.0, 3.0, 4.0),
    float2x2(5.0, 6.0, 7.0, 8.0)
};
const auto kMatrixArrayColumnSwizzle = kMatrixArray[1][0].yx;        // 第0列 (5,6) => float2(6.0, 5.0)
const auto kMatrixArrayDeterminant   = determinant(kMatrixArray[1]); // 5*8 - 6*7 = -2.0

// [多维数组与各层 length()]
ConstInt kNestedArray[2][3]  = {
    { 1, 2, 3 },
    { 4, 5, 6 }
};
const auto kNestedArrayElement     = kNestedArray[1][2];         // 期望: 6
const auto kNestedArrayOuterLength = kNestedArray.length();      // 期望: 2
const auto kNestedArrayInnerLength = kNestedArray[0].length();   // 期望: 3

// [多维向量数组的链式索引与 Swizzle]
using ConstFloat3 = const float3;
ConstFloat3 kNestedVectorArray[2][2] = {
    { float3(1.0, 2.0, 3.0), float3(4.0, 5.0, 6.0) },
    { float3(7.0, 8.0, 9.0), float3(10.0, 11.0, 12.0) }
};

const auto kNestedVectorArraySwizzle = kNestedVectorArray[1][0].zyx; // 期望: float3(9.0, 8.0, 7.0)

// ============================================================================
// 12. 复杂数组构造器（参考 OverloadTest.glsl）
// ============================================================================
// [临时数组构造器立即索引]
const auto kTemporaryScalarArrayIndex = intArray4(10, 20, 30, 40)[bitCount(3)]; // bitCount(3)=2，期望: 30
const auto kTemporaryVectorArrayIndex = 
    float3Array3(
        float3(1.0, 2.0, 3.0),
        float3(float2(4.0, 5.0), 6.0),
        float3(7.0)
    )[1].zxy; // (4,5,6).zxy => float3(6.0, 4.0, 5.0)

// [向量构造器参数展开 + 数组元素]
const auto kConstructorSourceArray[3] = float4Array3(
    float4(float2(1.0, 2.0), float2(3.0, 4.0)),
    float4(int2(5, 6), 7.0, 8.0),
    float4(float3(9.0, 10.0, 11.0), 12.0)
);

const auto kArrayElementReconstructed = float4(
    kConstructorSourceArray[2].w,
    kConstructorSourceArray[0].yx,
    kConstructorSourceArray[1].z
); // 期望: float4(12.0, 2.0, 1.0, 7.0)

const auto kArrayElementBuiltinChain = normalize(float3(
    kConstructorSourceArray[0].xy,
    length(kConstructorSourceArray[1].zw)
)); // 期望: normalize(float3(1.0, 2.0, sqrt(113.0)))

// [显式尺寸二维数组构造器]
const auto kConstructedInt2D[2][3] = intArray2D(
    intArray(1, 2, 3),
    intArray(4, 5, 6)
);
const auto kConstructedInt2DValue = kConstructedInt2D[kConstructedInt2D.length() - 1][kConstructedInt2D[0].length() - 2]; // [1][1]，期望: 5

// [所有维度均由构造参数推导]
const auto kDeducedFloat3D[][][]  = float3DArray(
    float2DArray(
        floatArray3(1.0, 2.0, 3.0),
        floatArray3(4.0, 5.0, 6.0)
    ),
    float2DArray(
        floatArray3(7.0, 8.0, 9.0),
        floatArray3(10.0, 11.0, 12.0)
    )
);
const auto kDeducedFloat3DValue        = kDeducedFloat3D[1][0][bitCount(7) - 1]; // bitCount(7)=3，[1][0][2]，期望: 9.0
const auto kDeducedFloat3DOuterLength  = kDeducedFloat3D.length();
const auto kDeducedFloat3DMiddleLength = kDeducedFloat3D[0].length();
const auto kDeducedFloat3DInnerLength  = kDeducedFloat3D[0][0].length(); // 均期望: 2, 2, 3

// [多维向量数组构造器 + 临时结果索引 + Swizzle]
const auto kConstructedVector3D[2][2][2] = float2Array3D(
    float2Array2D(
        float2Array(float2(1.0, 2.0), float2(3.0, 4.0)),
        float2Array(float2(5.0, 6.0), float2(7.0, 8.0))
    ),
    float2Array2D(
        float2Array(float2(9.0, 10.0), float2(11.0, 12.0)),
        float2Array(float2(13.0, 14.0), float2(15.0, 16.0))
    )
);

using float2Array2DDeduced = vec2[][];
using float2ArrayDeduced   = vec2[];

const auto kConstructedVector3DMix = float4(
    kConstructedVector3D[1][1][0].yx,
    float2Array2DDeduced(float2ArrayDeduced(float2(17.0), float2(18.0)))[0][1].xy
); // 期望: float4(14.0, 13.0, 18.0, 18.0)

// [矩阵构造器嵌入数组构造器]
const auto kConstructedMatrixArray[2] = float2x3Array(
    float2x3(
        float3(1.0, 2.0, 3.0),
        float3(float2(4.0, 5.0), 6.0)
    ),
    float2x3(
        float3(7.0, 8.0, 9.0),
        float3(10.0, 11.0, 12.0)
    )
);
const auto kConstructedMatrixColumn = kConstructedMatrixArray[1][bitCount(1)].zxy; // bitCount(1)=1，第1列 => float3(12,10,11)
const auto kConstructedMatrixDot = dot(
    kConstructedMatrixArray[0][0].zyx,
    kConstructedMatrixArray[1][1].xyz
); // (3,2,1) dot (10,11,12)，期望: 64.0

using float3Array3Deduced = vec3[];

// [数组元素参与矩阵、向量和内置函数的深层复合调用]
const auto kDeepArrayConstructorExpression = max(
    transpose(float3x3(
        kConstructorSourceArray[0].xyz,
        kConstructorSourceArray[1].xyz,
        kConstructorSourceArray[2].xyz
    ))[bitCount(1)].zyx,
    float3Array3Deduced(
        abs(kConstructorSourceArray[0].wzy),
        sqrt(kConstructorSourceArray[2].zyx)
    )[1]
); // 期望: max(float3(10,6,2), sqrt(float3(11,10,9))) = float3(10,6,3)

// ============================================================================
// 13. 结构体常量求值
// ============================================================================
struct ConstInner {
    int    v;
    float3 data;
};

struct ConstOuter {
    ConstInner inner;
    float      scale;
    int        indices[3];
};

using ConstInnerAlias = ConstInner;
using ConstOuterAlias = ConstOuter;
using ConstInnerArray = ConstInnerAlias[2];

const auto kStructInner = ConstInnerAlias(
    42,
    float3(1.0, 2.0, 3.0)
);

const auto kStructOuter = ConstOuterAlias(
    kStructInner,
    1.5,
    intArray(10, 20, 30)
);

const auto kStructNestedScalar  = kStructOuter.inner.v;                  // 期望: 42
const auto kStructNestedSwizzle = kStructOuter.inner.data.zy;            // 期望: float2(3.0, 2.0)
const auto kStructArrayField    = kStructOuter.indices[bitCount(3) - 1]; // 期望: 20

const auto kStructBuiltinExpression  = dot(
    kStructOuter.inner.data,
    float3(kStructOuter.scale)
); // 期望: 9.0

const auto kStructArray[2] = ConstInnerArray(
    ConstInnerAlias(10, float3(2.0)),
    ConstInnerAlias(20, float3(4.0))
);

const auto kStructArrayNestedField = kStructArray[1].v;                               // 期望: 20
const auto kStructArrayBuiltin     = max(kStructArray[0].data, kStructArray[1].data); // 期望: float3(4.0)

// ============================================================================
// 14. OverloadTest 风格的结构体大杂烩
// ============================================================================
struct InnerData {
    float Float;
    int   Int;
    float3  float3;
    float2x2  mat2Array1D_2[2];
    int   intArray2D_2x3[2][3];
};

struct MiddleData {
    InnerData Inner;
    float4      vec4Array1D_3[3];
    float4x4      float4x4;
};

struct OuterData {
    MiddleData Middle[2];
    double2      double2;
};
using InnerAlias  = InnerData;
using MiddleAlias = MiddleData;
using OuterAlias  = OuterData;
using MiddleArray = MiddleAlias[2];
using OuterArray  = OuterAlias[2];

const auto kInnerDataA = InnerAlias(
    1.25,
    7,
    float3(1.0, 2.0, 3.0),
    float2x2Array(
        float2x2(1.0, 2.0, 3.0, 4.0),
        float2x2(2.0, 0.0, 0.0, 3.0)
    ),
    intArray2D(
        intArray(1, 2, 3),
        intArray(4, 5, 6)
    )
);

const auto kInnerDataB = InnerAlias(
    -2.5,
    11,
    float3(4.0, 5.0, 6.0),
    float2x2Array(
        float2x2(4.0),
        float2x2(5.0, 6.0, 7.0, 8.0)
    ),
    intArray2D(
        intArray(7, 8, 9),
        intArray(10, 11, 12)
    )
);

const auto kMiddleDataA = MiddleAlias(
    kInnerDataA,
    float4Array3(
        float4(1.0, 2.0, 3.0, 4.0),
        float4(5.0, 6.0, 7.0, 8.0),
        float4(9.0, 10.0, 11.0, 12.0)
    ),
    float4x4(
        float4(1.0, 2.0, 3.0, 4.0),
        float4(5.0, 6.0, 7.0, 8.0),
        float4(9.0, 10.0, 11.0, 12.0),
        float4(13.0, 14.0, 15.0, 16.0)
    )
);

const auto kMiddleDataB = MiddleAlias(
    kInnerDataB,
    float4Array3(
        float4(16.0, 15.0, 14.0, 13.0),
        float4(12.0, 11.0, 10.0, 9.0),
        float4(8.0, 7.0, 6.0, 5.0)
    ),
    float4x4(
        float4(2.0, 0.0, 0.0, 0.0),
        float4(0.0, 3.0, 0.0, 0.0),
        float4(0.0, 0.0, 4.0, 0.0),
        float4(0.0, 0.0, 0.0, 5.0)
    )
);

const auto kOuterData = OuterAlias(
    MiddleArray(kMiddleDataA, kMiddleDataB),
    double2(0.5, 1.5)
);

// [连续结构体成员访问]
const auto kDeepStructInt    = kOuterData.Middle[1].Inner.Int;    // 期望: 11
const auto kDeepStructFloat  = kOuterData.Middle[0].Inner.Float;  // 期望: 1.25
const auto kDeepStructVector = kOuterData.Middle[1].Inner.float3; // 期望: float3(4.0, 5.0, 6.0)

// [结构体字段数组的各层 length()]
const auto kStructMiddleLength        = kOuterData.Middle.length();                            // 期望: 2
const auto kStructMatrixArrayLength   = kOuterData.Middle[0].Inner.mat2Array1D_2.length();     // 期望: 2
const auto kStructIntArrayOuterLength = kOuterData.Middle[1].Inner.intArray2D_2x3.length();    // 期望: 2
const auto kStructIntArrayInnerLength = kOuterData.Middle[1].Inner.intArray2D_2x3[0].length(); // 期望: 3

// [结构体 → 数组 → 数组 → 标量]
const auto kDeepStructArrayScalar = kOuterData.Middle[1].Inner.intArray2D_2x3[bitCount(3) - 1][bitCount(7) - 1]; // [1][2]，期望: 12

// [结构体 → 数组 → 向量 → Swizzle]
const auto kDeepStructArraySwizzle = kOuterData.Middle[0].vec4Array1D_3[2].wzx; // 期望: float3(12.0, 11.0, 9.0)

// [结构体 → 矩阵数组 → 矩阵列 → Swizzle]
const auto kDeepStructMatrixArrayColumn = kOuterData.Middle[0].Inner.mat2Array1D_2[0][1].yx; // 第1列 (3,4)，期望: float2(4.0, 3.0)
const auto kDeepStructMatrixColumn      = kOuterData.Middle[0].float4x4[2].wzx;              // 第2列 (9,10,11,12)，期望: float3(12,11,9)

// [取出字段后继续调用内置函数]
const auto kDeepStructDot = dot(
    kOuterData.Middle[0].Inner.float3,
    kOuterData.Middle[1].Inner.float3.zyx
); // (1,2,3) dot (6,5,4)，期望: 28.0

const auto kDeepStructDeterminant = determinant(
    kOuterData.Middle[0].Inner.mat2Array1D_2[1]
); // determinant(float2x2(2,0,0,3))，期望: 6.0

const auto kDeepStructBuiltinMix = max(
    abs(kOuterData.Middle[1].vec4Array1D_3[2].wzyx - float4(7.0)),
    sqrt(kOuterData.Middle[0].vec4Array1D_3[2].wzyx)
); // max((2,1,0,1), sqrt(12,11,10,9))

// [结构体字段参与新的结构体构造]
const auto kReconstructedInnerData = InnerAlias(
    abs(kOuterData.Middle[1].Inner.Float),
    kOuterData.Middle[0].Inner.Int + kOuterData.Middle[1].Inner.Int,
    max(
        kOuterData.Middle[0].Inner.float3,
        kOuterData.Middle[1].Inner.float3.zyx
    ),
    float2x2Array(
        transpose(kOuterData.Middle[0].Inner.mat2Array1D_2[0]),
        inverse(kOuterData.Middle[0].Inner.mat2Array1D_2[1])
    ),
    intArray2D(
        kOuterData.Middle[0].Inner.intArray2D_2x3[1],
        kOuterData.Middle[1].Inner.intArray2D_2x3[0]
    )
);

const auto kReconstructedStructInt        = kReconstructedInnerData.Int;                  // 期望: 18
const auto kReconstructedStructVector     = kReconstructedInnerData.float3;               // max((1,2,3),(6,5,4)) => float3(6,5,4)
const auto kReconstructedStructArrayValue = kReconstructedInnerData.intArray2D_2x3[1][2]; // 期望: 9

// [临时结构体构造结果立即进行成员、数组和 Swizzle 访问]
const auto kTemporaryStructMember = InnerAlias(
    3.5,
    99,
    float3(7.0, 8.0, 9.0),
    float2x2Array(float2x2(1.0), float2x2(2.0)),
    intArray2D(intArray(1, 2, 3), intArray(4, 5, 6))
).intArray2D_2x3[1][0]; // 期望: 4

const auto kTemporaryNestedStructSwizzle = MiddleAlias(
    kInnerDataA,
    float4Array3(float4(1.0), float4(2.0), float4(3.0, 4.0, 5.0, 6.0)),
    float4x4(1.0)
).vec4Array1D_3[2].wz; // 期望: float2(6.0, 5.0)

// [结构体数组构造结果立即索引并访问深层字段]
const auto kTemporaryStructArrayField = OuterArray(
    kOuterData,
    OuterAlias(
        MiddleArray(kMiddleDataB, kMiddleDataA),
        double2(2.5, 3.5)
    )
)[1].Middle[0].Inner.Float; // 期望: -2.5

const auto kTemporaryStructArrayDouble = OuterArray(
    kOuterData,
    OuterAlias(
        MiddleArray(kMiddleDataB, kMiddleDataA),
        double2(2.5, 3.5)
    )
)[1].double2.yx; // 期望: double2(3.5, 2.5)

// ============================================================================
// 15. 结构体大括号初始化
// ============================================================================
// [简单结构体]
using ConstConstInnerAlias = const ConstInner;
ConstConstInnerAlias kBraceSimpleInner = {
    64,
    float3(2.0, 4.0, 8.0)
};
const auto kBraceSimpleInnerValue   = kBraceSimpleInner.v;        // 期望: 64
const auto kBraceSimpleInnerSwizzle = kBraceSimpleInner.data.zyx; // 期望: float3(8.0, 4.0, 2.0)

// [嵌套结构体及结构体字段数组全部使用大括号]
using ConstConstOuterAlias = const ConstOuter;
ConstConstOuterAlias kBraceNestedOuter = {
    {
        65,
        float3(3.0, 6.0, 9.0)
    },
    2.5,
    { 100, 200, 300 }
};
const auto kBraceNestedStructValue = kBraceNestedOuter.inner.v;    // 期望: 65
const auto kBraceNestedArrayValue  = kBraceNestedOuter.indices[1]; // 期望: 200
const auto kBraceNestedBuiltin  = dot(
    kBraceNestedOuter.inner.data,
    float3(kBraceNestedOuter.scale)
); // (3+6+9)*2.5，期望: 45.0

// [结构体数组，每个元素均为大括号初始化的结构体]
ConstConstInnerAlias kBraceStructArray[3] = {
    { 10, float3(1.0, 2.0, 3.0) },
    { 20, float3(4.0, 5.0, 6.0) },
    { 30, float3(7.0, 8.0, 9.0) }
};
const auto kBraceStructArrayMember = kBraceStructArray[bitCount(3)].v; // bitCount(3)=2，期望: 30
const auto kBraceStructArrayMixed  = float4(
    kBraceStructArray[2].data.yx,
    kBraceStructArray[0].data.zy
); // 期望: float4(8.0, 7.0, 3.0, 2.0)

// [OverloadTest 的 InnerData 完全使用嵌套大括号初始化]
const InnerAlias kBraceInnerData = {
    6.25,
    123,
    float3(2.0, 3.0, 4.0),
    {
        float2x2(1.0, 2.0, 3.0, 4.0),
        float2x2(5.0, 6.0, 7.0, 8.0)
    },
    {
        { 11, 12, 13 },
        { 21, 22, 23 }
    }
};
const auto kBraceInnerDataFloat        = kBraceInnerData.Float;                  // 期望: 6.25
const auto kBraceInnerDataMatrixColumn = kBraceInnerData.mat2Array1D_2[1][0].yx; // 第0列 (5,6)，期望: float2(6.0, 5.0)
const auto kBraceInnerDataDeepArray    = kBraceInnerData.intArray2D_2x3[1][2];   // 期望: 23

// [MiddleData：结构体、向量数组和矩阵混合大括号初始化]
const MiddleAlias kBraceMiddleData = {
    {
        7.5,
        321,
        float3(5.0, 10.0, 15.0),
        {
            float2x2(2.0),
            float2x2(3.0)
        },
        {
            { 31, 32, 33 },
            { 41, 42, 43 }
        }
    },
    {
        float4(1.0, 2.0, 3.0, 4.0),
        float4(5.0, 6.0, 7.0, 8.0),
        float4(9.0, 10.0, 11.0, 12.0)
    },
    float4x4(
        float4(1.0, 0.0, 0.0, 0.0),
        float4(0.0, 2.0, 0.0, 0.0),
        float4(0.0, 0.0, 3.0, 0.0),
        float4(0.0, 0.0, 0.0, 4.0)
    )
};
const auto kBraceMiddleDeepMember    = kBraceMiddleData.Inner.intArray2D_2x3[0][1]; // 期望: 32
const auto kBraceMiddleVectorSwizzle = kBraceMiddleData.vec4Array1D_3[1].wzx;       // 期望: float3(8.0, 7.0, 5.0)
const auto kBraceMiddleMatrixVector  = kBraceMiddleData.float4x4 * float4(1.0);     // 期望: float4(1.0, 2.0, 3.0, 4.0)
// [OuterData 全层级大括号初始化]
const OuterAlias kBraceOuterData = {
    {
        kBraceMiddleData,
        {
            kBraceInnerData,
            {
                float4(20.0, 21.0, 22.0, 23.0),
                float4(24.0, 25.0, 26.0, 27.0),
                float4(28.0, 29.0, 30.0, 31.0)
            },
            float4x4(5.0)
        }
    },
    double2(9.5, 10.5)
};
const auto kBraceOuterDeepScalar    = kBraceOuterData.Middle[1].Inner.intArray2D_2x3[1][1]; // 期望: 22
const auto kBraceOuterDeepSwizzle   = kBraceOuterData.Middle[1].vec4Array1D_3[2].wz;        // 期望: float2(31.0, 30.0)
const auto kBraceOuterDoubleSwizzle = kBraceOuterData.double2.yx;                           // 期望: double2(10.5, 9.5)

// [大括号初始化的 OuterData 数组]
const OuterAlias kBraceOuterArray[2] = {
    kOuterData,
    {
        { kMiddleDataB, kBraceMiddleData },
        double2(20.5, 30.5)
    }
};
const auto kBraceOuterArrayNestedFloat   = kBraceOuterArray[1].Middle[1].Inner.Float; // 期望: 7.5
const auto kBraceOuterArrayNestedBuiltin = max(
    kBraceOuterArray[0].Middle[0].Inner.float3,
    kBraceOuterArray[1].Middle[0].Inner.float3
); // max((1,2,3),(4,5,6))，期望: float3(4,5,6)

// ============================================================================
// 16. 向量、矩阵与全层级大括号初始化
// ============================================================================
// [向量分量按目标类型解析，并进行允许的隐式转换]
const float4 kBraceVector         = { 1, 2.5, 3, 4.5 };
const int3   kBraceIntegerVector  = { -7, 8, -9 };
const bool4  kBraceBooleanVector  = { true, false, true, false };
const auto   kBraceVectorResult   = max(kBraceVector.wzy, abs(float3(kBraceIntegerVector))); // 期望: float3(7.0, 8.0, 9.0)

// [矩阵的每个初始化项对应一列向量]
const float2x2 kBraceMatrix2 = {
    { 1.0, 2.0 },
    { 3.0, 4.0 }
};
const float2x3 kBraceMatrix2x3 = {
    { 1, 2, 3 },
    { 4, 5, 6 }
};
const auto kBraceMatrixColumnSwizzle = kBraceMatrix2x3[1].zy;                 // 期望: float2(6.0, 5.0)
const auto kBraceMatrixDeterminant   = determinant(kBraceMatrix2);            // 期望: -2.0
const auto kBraceMatrixVectorProduct = kBraceMatrix2x3 * kBraceVector.xy;     // 期望: float3(11.0, 14.5, 18.0)

// [未定长数组从初始化列表推导外层长度]
const float3 kBraceDeducedVectorArray[] = {
    { 1.0, 2.0, 3.0 },
    { 4.0, 5.0, 6.0 },
    { 7.0, 8.0, 9.0 }
};
const auto kBraceDeducedVectorArrayLength = kBraceDeducedVectorArray.length(); // 期望: 3
const auto kBraceDeducedVectorArrayValue  = kBraceDeducedVectorArray[2].zx;    // 期望: float2(9.0, 7.0)

const float2x2 kBraceDeducedMatrixArray[] = {
    { { 1.0, 2.0 }, { 3.0, 4.0 } },
    { { 5.0, 6.0 }, { 7.0, 8.0 } }
};
const auto kBraceDeducedMatrixColumn = kBraceDeducedMatrixArray[1][0].yx;        // 期望: float2(6.0, 5.0)
const auto kBraceDeducedMatrixDet    = determinant(kBraceDeducedMatrixArray[1]); // 期望: -2.0

// [结构体字段中的向量、矩阵和数组全部使用大括号]
const InnerAlias kBraceAllCompositeInner = {
    8.5,
    456,
    { 2.0, 4.0, 8.0 },
    {
        { { 1.0, 2.0 }, { 3.0, 4.0 } },
        { { 5.0, 6.0 }, { 7.0, 8.0 } }
    },
    {
        { 51, 52, 53 },
        { 61, 62, 63 }
    }
};
const auto kBraceAllCompositeVector = kBraceAllCompositeInner.float3.zyx;             // 期望: float3(8.0, 4.0, 2.0)
const auto kBraceAllCompositeColumn = kBraceAllCompositeInner.mat2Array1D_2[1][1].yx; // 期望: float2(8.0, 7.0)
const auto kBraceAllCompositeArray  = kBraceAllCompositeInner.intArray2D_2x3[1][2];   // 期望: 63
const auto kBraceAllCompositeStable = dot(
    kBraceAllCompositeInner.float3,
    float3(kBraceAllCompositeInner.mat2Array1D_2[0] * kBraceVector.xy, kBraceAllCompositeInner.Float)
); // dot((2,4,8), (8.5,12.0,8.5))，期望: 133.0

void main() {
    return;
}
