#pragma once
#include <math.h>

template<typename T> struct vec2 {
  T x, y;
  template<typename R> explicit operator vec2<R>() { return {(R)x, (R)y}; }
};

template<typename T> struct vec3 {
  T x, y, z;
  template<typename R> explicit operator vec3<R>() { return {(R)x, (R)y, (R)z}; }
};

typedef struct {
  vec2<float> angle;
} angle;

// Dot product
template<typename T> float operator * (vec2<T> const& a, vec2<T> const& b) { return a.x*b.x + a.y*b.y; }
template<typename T> float operator * (vec3<T> const& a, vec3<T> const& b) { return a.x*b.x + a.y*b.y + a.z*b.z; }

// Vector addition
template<typename T> vec2<T> operator - (vec2<T> const& a, vec2<T> const& b) { return {a.x - b.x, a.y - b.y}; }
template<typename T> vec2<T> operator + (vec2<T> const& a, vec2<T> const& b) { return {a.x + b.x, a.y + b.y}; }
template<typename T> vec3<T> operator - (vec3<T> const& a, vec3<T> const& b) { return {a.x - b.x, a.y - b.y, a.z - b.z}; }
template<typename T> vec3<T> operator + (vec3<T> const& a, vec3<T> const& b) { return {a.x + b.x, a.y + b.y, a.z + b.z}; }

// Vector scaling
template<typename T> T operator *(T const& val, float const& scale);
template<typename T> T operator *(float const& scale, T const& val);

// Vector scaling
template<typename T> vec2<T> operator * (vec2<T> const& vector, float const& scale) { return {vector.x * scale, vector.y * scale}; }
template<typename T> vec2<T> operator * (float const& scale, vec2<T> const& vector) { return {vector.x * scale, vector.y * scale}; }
template<typename T> vec3<T> operator * (vec3<T> const& vector, float const& scale) { return {vector.x * scale, vector.y * scale, vector.z * scale}; }
template<typename T> vec3<T> operator * (float const& scale, vec3<T> const& vector) { return {vector.x * scale, vector.y * scale, vector.z * scale}; }

//template<typename T> vec2<T> operator * (vec2<T> &vector, float &scale) { return {vector.x * scale, vector.y * scale}; }
//template<typename T> vec2<T> operator * (float &scale, vec2<T> &vector) { return {vector.x * scale, vector.y * scale}; }
//template<typename T> vec3<T> operator * (vec3<T> &vector, float &scale) { return {vector.x * scale, vector.y * scale, vector.z * scale}; }
//template<typename T> vec3<T> operator * (float &scale, vec3<T> &vector) { return {vector.x * scale, vector.y * scale, vector.z * scale}; }

template<typename T> vec2<T> operator / (vec2<T> const& vector, float const& scale) { return {vector.x / scale, vector.y / scale}; }
template<typename T> vec3<T> operator / (vec3<T> const& vector, float const& scale) { return {vector.x / scale, vector.y / scale, vector.z / scale}; }

namespace MathUtils {

  template<typename T> T signum(T const& value); // Returns the sign of the number or zero if the number is zero

  angle angleFromRadians(float radians);
  angle angleFromDegrees(float degrees);
  angle angleFromRotations(float rotations);

  float getRadians(angle angle);
  float getDegrees(angle angle);
  float getRotations(angle angle);

  template<typename T> float dot(vec3<T> const& a, vec3<T> const& b) { return a.x*b.x + a.y*b.y + a.z*b.z; }


  template<typename T> vec3<T> cross(vec3<T> const& a, vec3<T> const& b) {
    return {
      a.y*b.z - b.y*a.z,
      a.z*b.x - b.z*a.x,
      a.x*b.y - b.x*a.y
    };
  }

  vec2<float> inverse_2dof(vec2<float> origin, vec2<float> target, float l1, float l2);

  template<typename T, typename R> vec3<T> multiplyComponents(vec3<T> const& a, vec3<R> const& b) {
    return {a.x * b.x, a.y * b.y, a.z * b.z};
  }

  template<typename T, typename R> vec3<T> divideComponents(vec3<T> const& a, vec3<R> const& b) {
    return {a.x / b.x, a.y / b.y, a.z / b.z};
  }

  template<typename T, typename R> vec2<T> multiplyComponents(vec2<T> const& a, vec2<R> const& b) {;
    return {a.x * b.x, a.y * b.y};
  }

  angle negate_angle(angle const& angle);

  template<typename T>
  T rotate(T const& vector, angle const& angle);
  
  template<typename T>
  float length(T const& vector) {
    return sqrt(vector * vector);
  }

  template<typename T>
  float fastLength(vec2<T> const& vector) {
    return hypot(vector.x, vector.y);
  }

  template<typename T>
  angle direction(T const& vector);

  template<typename T>
  T normalize(T const& vector) {
    return vector / sqrt(vector * vector);
  }

  vec3<float> getAxisAngleRotation(vec3<float> const& a, vec3<float> const& b);

  template<typename T> T rotate3d(T const& vec, vec3<float> const& rotation) {
    float theta = length(rotation); //69us 85
    float cos_theta = cos(theta); //120us 120
    vec3<float> axis = rotation / theta; //92us 93

    return (cos_theta * vec) + (sin(theta) * cross(axis, vec)) + ((1-cos_theta) * (axis * vec) * axis);
  }

  template<typename T> angle angle_between_vectors(T const& a, T const& b) {
    return {{a.x* b.x + a.y*b.y + a.z * b.z, length<vec3<float>>(cross(a, b))}};
//    return {{a*b, length<vec3<float>>(cross(a, b))}};
  }

  template<typename T, typename R>
  T clamp(T const& value, R const& range_min, R const& range_max) {
    return ((value <= range_min) * range_min + (value>range_min)* value) * (value < range_max) + range_max * (value >= range_max);
  }
}

// Angle addition
inline angle operator + (angle const& a, angle const& b) { return {a.angle.x * b.angle.x - a.angle.y * b.angle.y, b.angle.x * a.angle.y + b.angle.y * a.angle.x }; };
inline angle operator - (angle const& a, angle const& b) { return a + MathUtils::negate_angle(b); }
