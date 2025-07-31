const std = @import("std");

fn swap_range(comptime T: type, a: []T, b: []T) void {
    std.debug.assert(a.len == b.len);
    for (0..a.len) |i| {
        std.mem.swap(T, &a[i], &b[i]);
    }
}

pub fn Mat(my_rows: usize, my_cols: usize, T: type) type {
    return struct {
        comptime rows: usize = my_rows,
        comptime cols: usize = my_cols,
        m: [my_rows * my_cols]T,

        pub fn new(matrix: [my_rows * my_cols]T) @This() {
            return .{
                .m = matrix,
            };
        }

        pub fn identity() @This() {
            var mat: @This() = undefined;
            for (0..my_rows) |row_idx| {
                for (0..my_cols) |col_idx| {
                    mat.m[row_idx * my_cols + col_idx] = if (col_idx == row_idx) 1 else 0;
                }
            }
            return mat;
        }

        pub fn vectorize(self: @This()) @Vector(my_rows * my_cols, T) {
            return @as(@Vector(my_rows * my_cols, T), self.m);
        }

        pub fn add(self: @This(), other: @This()) @This() {
            var result: @This() = undefined;
            result.m = self.vectorize() + other.vectorize();
            return result;
        }
        pub fn sub(self: @This(), other: @This()) @This() {
            var result: @This() = undefined;
            result.m = self.vectorize() - other.vectorize();
            return result;
        }
        pub fn hadamard(self: @This(), other: @This()) @This() {
            var result: @This() = undefined;
            result.m = self.vectorize() * other.vectorize();
            return result;
        }

        pub fn row(self: @This(), row_idx: usize) Vec(my_cols, T) {
            var result = Vec(my_cols, T).new(undefined);
            std.mem.copyForwards(T, &result.d, self.m[row_idx * my_cols .. (row_idx + 1) * my_cols]);
            return result;
        }

        pub fn row_slice(self: *@This(), row_idx: usize) []T {
            return self.m[row_idx * my_cols .. (row_idx + 1) * my_cols];
        }

        pub fn col(self: @This(), col_idx: usize) Vec(my_rows, T) {
            var result: Vec(my_rows, T) = undefined;
            for (0..my_rows) |row_idx| {
                result.d[row_idx] = self.m[row_idx * my_cols + col_idx];
            }
            return result;
        }

        pub fn mul(self: @This(), other: anytype) Mat(my_rows, other.cols, T) {
            comptime {
                std.debug.assert(@TypeOf(self.m[0]) == @TypeOf(other.m[0]));
                std.debug.assert(my_cols == other.rows);
            }

            var result: Mat(my_rows, other.cols, T) = undefined;
            for (0..my_rows) |row_idx| {
                for (0..other.cols) |col_idx| {
                    result.m[row_idx * other.cols + col_idx] = self.row(row_idx).dot(other.col(col_idx));
                }
            }
            return result;
        }

        pub fn transpose(self: @This()) @This() {
            var result: Mat(my_cols, my_rows, T) = undefined;
            for (0..my_rows) |row_idx| {
                for (0..my_cols) |col_idx| {
                    result.m[col_idx * my_rows + row_idx] = self.m[row_idx * my_cols + col_idx];
                }
            }
            return result;
        }

        pub fn transform(self: @This(), other: Vec(my_rows, T)) Vec(my_cols, T) {
            return self.mul(other.col_matrix()).col(0);
        }

        pub fn scale(self: @This(), scalar: T) @This() {
            return @This().new(self.vectorize() * @as(@Vector(my_rows * my_cols, T), @splat(scalar)));
        }

        pub fn reshape(self: @This(), comptime new_rows: usize, comptime new_cols: usize) Mat(new_rows, new_cols, T) {
            comptime std.debug.assert(new_rows * new_cols == my_rows * my_cols);
            return Mat(new_rows, new_cols, T).new(self.d);
        }

        // Original implementation courtesy of Logan Brown!
        pub fn inverse(self: @This()) ?@This() {
            std.debug.assert(self.rows == self.cols);
            const width = self.rows;
            var processing_mat = self;
            var result = @This().identity();

            //bottom half
            for (0..self.cols) |x| {
                // Move highest number in column to the current slot and scale to 1
                {
                    const ii_val = processing_mat.m[x * processing_mat.cols + x];
                    var best_val: T = 0;
                    var best_y: usize = 0;
                    for (x..processing_mat.cols) |y| {
                        const val = processing_mat.m[x + y * processing_mat.cols];
                        if (@abs(val) > @abs(best_val)) {
                            best_val = val;
                            best_y = y;
                        }
                    }
                    if (best_val == 0) {
                        return null; // not invertable
                    }

                    // Matrix.addScaleRow(proccesingMat,proccesingMat,(1-iiVal)/bestVal,bestY,x);
                    std.mem.copyForwards(T, processing_mat.row_slice(x), &@as([width]T, processing_mat.row(x).vectorize() + processing_mat.row(best_y).scale((1 - ii_val) / best_val).vectorize()));
                    // Matrix.addScaleRow(outMat,outMat,(1-iiVal)/bestVal,bestY,x);
                    std.mem.copyForwards(T, result.row_slice(x), &@as([width]T, result.row(x).vectorize() + result.row(best_y).scale((1 - ii_val) / best_val).vectorize()));
                }
                //Clear column below
                for (x + 1..width) |y| {
                    const val = processing_mat.m[x + y * processing_mat.cols];
                    std.mem.copyForwards(T, processing_mat.row_slice(y), &@as([width]T, processing_mat.row(y).vectorize() + processing_mat.row(x).scale(-val).vectorize()));
                    // Matrix.addScaleRow(proccesingMat,proccesingMat,-val,x,y);
                    std.mem.copyForwards(T, result.row_slice(y), &@as([width]T, result.row(y).vectorize() + result.row(x).scale(-val).vectorize()));
                    // Matrix.addScaleRow(outMat,outMat,-val,x,y);
                }
            }

            //Top half
            for (0..self.cols) |x| {
                var y = x;
                while (y > 0) {
                    y -= 1;
                    const val = processing_mat.m[x + y * processing_mat.cols];
                    std.mem.copyForwards(T, processing_mat.row_slice(y), &@as([width]T, processing_mat.row(y).vectorize() + processing_mat.row(x).scale(-val).vectorize()));
                    // Matrix.addScaleRow(proccesingMat, proccesingMat, -val, x, y);
                    std.mem.copyForwards(T, result.row_slice(y), &@as([width]T, result.row(y).vectorize() + result.row(x).scale(-val).vectorize()));
                    // Matrix.addScaleRow(outMat, outMat, -val, x, y);
                }
            }
            return result;
        }
    };
}

pub fn perspective_matrix(T: type, fov: T, aspect: T, start: T, end: T) Mat(4, 4, T) {
    const tfov2f = std.math.tan(fov / 2.0);
    return Mat(4, 4, T).new(.{
        1.0 / (aspect * tfov2f), 0, 0, 0, //
        0, 1.0 / (tfov2f), 0, 0, //
        0, 0, (end) / (end - start), -(end * start) / (end - start), //
        0, 0, 1,                     0,
    });
}

pub fn ortho_matrix(T: type, left: T, right: T, bottom: T, top: T, start: T, end: T) Mat(4, 4, T) {
    return Mat(4, 4, T).new(.{
        2 / (right - left), 0, 0, -(right + left) / (right - left), //
        0, 2 / (top - bottom), 0, -(top + bottom) / (top - bottom), //
        0, 0, 1 / (end - start), -start / (end - start), //
        0, 0, 0, 1, //
    });
}

pub fn translation_matrix(T: type, translation: Vec(3, T)) Mat(4, 4, T) {
    return Mat(4, 4, T).new(.{
        1, 0, 0, translation.d[0], //
        0, 1, 0, translation.d[1], //
        0, 0, 1, translation.d[2], //
        0, 0, 0, 1,
    });
}

pub fn rotation_axis_angle(T: type, axis: Vec(3, T), angle: T) Mat(4, 4, T) {
    const uaxis = axis.unit();
    const s = std.math.sin(-angle);
    const c = std.math.cos(angle);
    const oc = 1.0 - c;

    return Mat(4, 4, T).new(.{
        oc * uaxis.d[0] * uaxis.d[0] + c, oc * uaxis.d[0] * uaxis.d[1] - uaxis.d[2] * s, oc * uaxis.d[2] * uaxis.d[0] + uaxis.d[1] * s, 0.0, //
        oc * uaxis.d[0] * uaxis.d[1] + uaxis.d[2] * s, oc * uaxis.d[1] * uaxis.d[1] + c, oc * uaxis.d[1] * uaxis.d[2] - uaxis.d[0] * s, 0.0, //
        oc * uaxis.d[2] * uaxis.d[0] - uaxis.d[1] * s, oc * uaxis.d[1] * uaxis.d[2] + uaxis.d[0] * s, oc * uaxis.d[2] * uaxis.d[2] + c, 0.0, //
        0.0, 0.0, 0.0, 1.0, //
    });
}

pub fn scale_matrix(T: type, scale: Vec(3, T)) Mat(4, 4, T) {
    return Mat(4, 4, T).new(.{
        scale.d[0], 0, 0, 0, //
        0, scale.d[1], 0, 0, //
        0, 0, scale.d[2], 0, //
        0, 0, 0,          1,
    });
}

pub fn Vec(components: usize, T: type) type {
    return struct {
        comptime comps: usize = components,
        d: [components]T,

        pub fn col_matrix(self: @This()) Mat(components, 1, T) {
            return Mat(components, 1, T).new(self.d);
        }

        pub fn row_matrix(self: @This()) Mat(1, components, T) {
            return Mat(1, components, T).new(self.d);
        }

        // left multiply the vector
        pub fn transform(self: @This(), other: anytype) Vec(other.cols, T) {
            return self.mul(other.col_matrix()).col(0);
        }

        pub fn new(vec: [components]T) @This() {
            return .{ .d = vec };
        }

        pub fn a(scalar: T) @This() {
            return @This().new(@as(@Vector(components, T), @splat(scalar)));
        }

        pub fn vectorize(self: @This()) @Vector(components, T) {
            return @as(@Vector(components, T), self.d);
        }

        pub fn add(self: @This(), other: @This()) @This() {
            var result: @This() = undefined;
            result.d = self.vectorize() + other.vectorize();
            return result;
        }

        pub fn sub(self: @This(), other: @This()) @This() {
            var result: @This() = undefined;
            result.d = self.vectorize() - other.vectorize();
            return result;
        }

        pub fn mul(self: @This(), other: @This()) @This() {
            var result: @This() = undefined;
            result.d = self.vectorize() * other.vectorize();
            return result;
        }

        pub fn div(self: @This(), other: @This()) @This() {
            var result: @This() = undefined;
            result.d = self.vectorize() / other.vectorize();
            return result;
        }

        pub fn scale(self: @This(), scalar: T) @This() {
            return @This().new(self.vectorize() * @as(@Vector(components, T), @splat(scalar)));
        }

        pub fn dot(self: @This(), other: @This()) T {
            return @reduce(.Add, self.mul(other).vectorize());
        }

        pub fn norm_sq(self: @This()) T {
            return self.dot(self);
        }

        pub fn norm(self: @This()) T {
            return std.math.sqrt(self.norm_sq());
        }

        pub fn unit(self: @This()) @This() {
            const len = self.norm();
            if (len > 0) {
                return self.scale(1.0 / len);
            } else {
                return self;
            }
        }

        pub fn abs(self: @This()) @This() {
            var copy = self;
            for (&copy.d) |*it| {
                it.* *= std.math.sign(it.*);
            }
            return copy;
        }

        pub fn mix(self: @This(), other: @This(), mixer: f32) @This() {
            return self.scale(1 - mixer).add(other.scale(mixer));
        }

        pub fn map(self: @This(), context: anytype) switch (@typeInfo(@TypeOf(context.map))) {
            .Fn => |fn_data| Vec(components, fn_data.return_type.?),
            else => @compileError("Invalid context struct, it must contain a function map!"),
        } {
            var result: switch (@typeInfo(@TypeOf(context.map))) {
                .Fn => |fn_data| Vec(components, fn_data.return_type.?),
                else => @compileError("Invalid context struct, it must contain a function map!"),
            } = undefined;
            for (&result.d, self.d) |*you, me| {
                you.* = context.map(me);
            }
            return result;
        }

        pub fn min(self: @This(), other: @This()) @This() {
            return @This().new(@min(self.vectorize(), other.vectorize()));
        }
        pub fn max(self: @This(), other: @This()) @This() {
            return @This().new(@max(self.vectorize(), other.vectorize()));
        }

        pub fn clamp(self: @This(), vmin: @This(), vmax: @This()) @This() {
            var result = self;
            for (&result.d, vmin.d, vmax.d) |*me, min_val, max_val| {
                me.* = std.math.clamp(me.*, min_val, max_val);
            }
            return result;
        }

        pub fn pow(self: @This(), exp: @This()) @This() {
            var result = self;
            for (&result.d, exp.d) |*me, exp_val| {
                me.* = std.math.pow(T, me.*, exp_val);
            }
            return result;
        }

        pub fn cross(lhs: Vec(3, T), rhs: Vec(3, T)) Vec3f {
            return Vec3f.new(.{
                lhs.d[1] * rhs.d[2] - lhs.d[2] * rhs.d[1],
                lhs.d[2] * rhs.d[0] - lhs.d[0] * rhs.d[2],
                lhs.d[0] * rhs.d[1] - lhs.d[1] * rhs.d[0],
            });
        }
    };
}

pub const Vec2f = Vec(2, f32);
pub const Vec3f = Vec(3, f32);
pub const Vec4f = Vec(4, f32);

pub const Vec2u = Vec(2, u32);
pub const Vec3u = Vec(3, u32);
pub const Vec4u = Vec(4, u32);

pub const Vec2i = Vec(2, i32);
pub const Vec3i = Vec(3, i32);
pub const Vec4i = Vec(4, i32);

pub const Vec2b = Vec(2, bool);
pub const Vec3b = Vec(3, bool);
pub const Vec4b = Vec(4, bool);
