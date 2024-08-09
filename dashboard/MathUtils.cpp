#include "MathUtils.h"
#include <math.h>



namespace MathUtils {
  angle angleFromRadians(float radians) { return {{cos(radians), sin(radians)}};}
  angle angleFromDegrees(float degrees) { return angleFromRadians(degrees * (float)M_PI / 180.0f); }
  angle angleFromRotations(float rotations) { return angleFromRadians(rotations * 2 * (float)M_PI); }

  float getRadians(angle angle) { return atan2(angle.angle.y, angle.angle.x); }
  float getDegrees(angle angle) { return getRadians(angle) * 180.0f / (float) M_PI; }
  float getRotations(angle angle) { return getRadians(angle) / (2 * (float)M_PI); }

  template<> float signum<float>(float const& value) {
    return (0 < value) - (value < 0); // Returns the sign of the number or zero if the number is zerop
  }

  template<> vec3<float> signum<vec3<float>>(vec3<float> const& vec) {
    return (vec3<float>) vec3<int>{(0 < vec.x) - (vec.x < 0), (0 < vec.y) - (vec.y < 0), (0 < vec.z) - (vec.z < 0)}; // Returns the sign of the number or zero if the number is zerop
  }

  vec3<float> getAxisAngleRotation(vec3<float> const& a, vec3<float> const& b) {
    vec3<float> v = cross(a, b);
    float cos_theta = length<vec3<float>>(v);
    float sin_theta = a * b;
    return (v * atan2(cos_theta, sin_theta))/cos_theta;
  }

  vec2<float> inverse_2dof(vec2<float> const& origin, vec2<float> const& target, float const& l1, float const& l2) {
    float len_target = length<vec2<float>>(target);
    vec2<float> q = target * (((l1*l1 - l2*l2) / len_target) + len_target);
    float l3 = sqrt(l1 * l1 - q*q);
    return q + ((vec2<float>){-q.y, q.x} * (l3/length<vec2<float>>(q)));
  }

  template<> vec2<float> rotate<vec2<float>>(vec2<float> const& vector, angle const& angle) {
    return {angle.angle.x * vector.x - angle.angle.y * vector.y, vector.x * angle.angle.y + vector.y * angle.angle.x };
  }

  angle negate_angle(angle const& angle) {
    return {{angle.angle.x, -angle.angle.y}};
  }

  template<> angle direction<vec2<float>>(vec2<float> const& vector) {
    return {normalize(vector)};
  }
}

