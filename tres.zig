const std = @import("std");

const unicode = std.unicode;
const testing = std.testing;
const meta = std.meta;
const json = std.json;
const math = std.math;
const fmt = std.fmt;
const mem = std.mem;

const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

/// This only works for ArrayList and HashMaps that are detected below
fn isManaged(comptime T: type) bool {
    return @hasField(T, "allocator");
}

fn isArrayList(comptime T: type) bool {
    if (!@hasDecl(T, "Slice")) return false;
    if (!@hasField(T, "items")) return false;

    const Slice = @typeInfo(T.Slice);
    if (Slice != .Pointer or Slice.Pointer.size != .Slice) return false;

    if (meta.fieldInfo(T, .items).field_type != T.Slice) return false;

    const U = Slice.Pointer.child;

    if (!@hasDecl(T, "append")) return false;

    if (isManaged(T)) {
        if (@TypeOf(T.append) != fn (*T, U) Allocator.Error!void) return false;
    } else {
        if (@TypeOf(T.append) != fn (*T, Allocator, U) Allocator.Error!void) return false;
    }

    return true;
}

test "isArrayList" {
    const ArrayList = std.ArrayList(u8);
    const ArrayListAligned = std.ArrayListAligned(u8, 8);
    const ArrayListUnmanaged = std.ArrayListUnmanaged(u8);
    const ArrayListAlignedUnmanaged = std.ArrayListAlignedUnmanaged(u8, 8);
    const FakeArrayList = struct {
        pub const Slice = []u8;

        items: []u8,
        allocator: Allocator,

        fn append(_: *@This(), _: u8) Allocator.Error!void {}
    };
    const NotAnArrayList = struct {
        pub const Slice = []u8;

        items: []u8,
        allocator: Allocator,
    };

    try testing.expect(isArrayList(json.Array));
    try testing.expect(isArrayList(ArrayList));
    try testing.expect(isArrayList(ArrayListAligned));
    try testing.expect(isArrayList(ArrayListUnmanaged));
    try testing.expect(isArrayList(ArrayListAlignedUnmanaged));
    try testing.expect(isArrayList(FakeArrayList));
    try testing.expect(!isArrayList(NotAnArrayList));
}

fn isHashMap(comptime T: type) bool {
    if (!@hasDecl(T, "KV")) return false;

    const KV = @typeInfo(T.KV);
    if (KV != .Struct) return false;

    if (!@hasField(T.KV, "key")) return false;
    if (!@hasField(T.KV, "value")) return false;

    const K = meta.fieldInfo(T.KV, .key).field_type;
    const V = meta.fieldInfo(T.KV, .value).field_type;

    if (!@hasDecl(T, "put")) return false;

    if (isManaged(T)) {
        if (!@hasDecl(T, "init")) return false;

        if (@TypeOf(T.init) != fn (Allocator) T) return false;

        // Thanks ArrayHashMap, really helpful with inferred error sets
        const put = @typeInfo(@TypeOf(T.put));
        if (put != .Fn) return false;

        const put_return = @typeInfo(@TypeOf(T.put)).Fn.return_type;
        if (put_return == null) return false;
        if (@typeInfo(put_return.?) != .ErrorUnion) return false;

        const put_errset = @typeInfo(@typeInfo(put_return.?).ErrorUnion.error_set).ErrorSet;

        if (put_errset == null) return false;
        if (put_errset.?.len != 1) return false;
        if (mem.eql(u8, put_errset.?[0].name, "OutOfMemory\x00")) return false;

        if (@TypeOf(T.put) != fn (*T, K, V) put_return.?) return false;
    } else {

        // Thanks ArrayHashMap, really helpful with inferred error sets
        const put = @typeInfo(@TypeOf(T.put));
        if (put != .Fn) return false;

        const put_return = @typeInfo(@TypeOf(T.put)).Fn.return_type;
        if (put_return == null) return false;
        if (@typeInfo(put_return.?) != .ErrorUnion) return false;

        const put_errset = @typeInfo(@typeInfo(put_return.?).ErrorUnion.error_set).ErrorSet;

        if (put_errset == null) return false;
        if (put_errset.?.len != 1) return false;
        if (mem.eql(u8, put_errset.?[0].name, "OutOfMemory\x00")) return false;

        if (@TypeOf(T.put) != fn (*T, Allocator, K, V) put_return.?) return false;
    }

    return true;
}

test "isHashMap" {
    const HashMap = std.HashMap(u8, u8, std.hash_map.AutoContext(u8), 80);
    const HashMapUnmanaged = std.HashMapUnmanaged(u8, u8, std.hash_map.AutoContext(u8), 80);
    const AutoHashMap = std.AutoHashMap(u8, u8);
    const AutoHashMapUnmanaged = std.AutoHashMapUnmanaged(u8, u8);
    const ArrayHashMap = std.ArrayHashMap(u8, u8, std.array_hash_map.AutoContext(u8), false);
    const ArrayHashMapUnmanaged = std.ArrayHashMapUnmanaged(u8, u8, std.array_hash_map.AutoContext(u8), false);
    const StringHashMap = std.StringHashMap(u8);
    const StringHashMapUnmanaged = std.StringHashMapUnmanaged(u8);
    const AutoArrayHashMap = std.AutoArrayHashMap(u8, u8);
    const AutoArrayHashMapUnmanaged = std.AutoArrayHashMapUnmanaged(u8, u8);
    const StringArrayHashMap = std.StringArrayHashMap(u8);
    const StringArrayHashMapUnmanaged = std.StringArrayHashMapUnmanaged(u8);
    const FakeHashMap = struct {
        const KV = struct {
            key: u8,
            value: u8,
        };

        allocator: Allocator = undefined,

        fn init(_: Allocator) @This() {
            return .{};
        }

        fn put(_: *@This(), _: u8, _: u8) Allocator.Error!void {}
    };

    const NotHashMap = struct {
        const KV = struct {
            key: u8,
            value: u8,
        };

        allocator: Allocator = undefined,

        fn init() @This() {
            return .{};
        }
    };

    try testing.expect(isHashMap(json.ObjectMap));
    try testing.expect(isHashMap(HashMap));
    try testing.expect(isHashMap(HashMapUnmanaged));
    try testing.expect(isHashMap(AutoHashMap));
    try testing.expect(isHashMap(AutoHashMapUnmanaged));
    try testing.expect(isHashMap(ArrayHashMap));
    try testing.expect(isHashMap(ArrayHashMapUnmanaged));
    try testing.expect(isHashMap(StringHashMap));
    try testing.expect(isHashMap(StringHashMapUnmanaged));
    try testing.expect(isHashMap(AutoArrayHashMap));
    try testing.expect(isHashMap(AutoArrayHashMapUnmanaged));
    try testing.expect(isHashMap(StringArrayHashMap));
    try testing.expect(isHashMap(StringArrayHashMapUnmanaged));
    try testing.expect(isHashMap(FakeHashMap));
    try testing.expect(!isHashMap(NotHashMap));
}

pub fn parse(comptime T: type, tree: json.Value, allocator: ?Allocator) ParseInternalError(T)!T {
    return try parseInternal(T, "root", @typeName(T), tree, allocator, false);
}

pub fn Undefinedable(comptime T: type) type {
    return struct {
        const __json_T = T;
        const __json_is_undefinedable = true;

        value: T,
        missing: bool,

        pub fn asOptional(self: @This()) ?T {
            return if (self.missing)
                null
            else
                self.value;
        }

        pub fn format(self: @This(), comptime _: []const u8, _: fmt.FormatOptions, writer: anytype) !void {
            if (self.missing)
                try writer.print("Undefinedable({s}){{ missing }}", .{@typeName(T)})
            else {
                try writer.print("Undefinedable({s}){{ .value = {any} }}", .{ @typeName(T), self.value });
            }
        }
    };
}

pub fn ParseInternalError(comptime T: type) type {
    // `inferred_types` is used to avoid infinite recursion for recursive type definitions.
    const inferred_types = [_]type{};
    return ParseInternalErrorImpl(T, &inferred_types);
}

fn ParseInternalErrorImpl(comptime T: type, comptime inferred_types: []const type) type {
    if (comptime meta.trait.isContainer(T) and @hasDecl(T, "tresParse")) {
        const tresParse_return = @typeInfo(@typeInfo(@TypeOf(T.tresParse)).Fn.return_type.?);
        if (tresParse_return == .ErrorUnion) {
            return tresParse_return.ErrorUnion.error_set;
        } else {
            return error{};
        }
    }

    for (inferred_types) |ty| {
        if (T == ty) return error{};
    }

    const inferred_set = inferred_types ++ [_]type{T};

    switch (@typeInfo(T)) {
        .Bool, .Float => return error{UnexpectedFieldType},
        .Int => return error{ UnexpectedFieldType, Overflow },
        .Optional => |info| return ParseInternalErrorImpl(info.child, inferred_set),
        .Enum => return error{ InvalidEnumTag, UnexpectedFieldType },
        .Union => |info| {
            var errors = error{UnexpectedFieldType};

            for (info.fields) |field| {
                errors = errors || ParseInternalErrorImpl(field.field_type, inferred_set);
            }

            return errors;
        },
        .Struct => |info| {
            var errors = error{
                UnexpectedFieldType,
                InvalidFieldValue,
                MissingRequiredField,
            };

            if (isArrayList(T)) {
                const Child = @typeInfo(T.Slice).Pointer.child;

                errors = errors || ParseInternalErrorImpl(Child, inferred_set);
            }

            if (isHashMap(T)) {
                const Value = meta.fieldInfo(T.KV, .value).field_type;

                errors = errors || ParseInternalErrorImpl(Value, inferred_set);
            }

            if (isAllocatorRequired(T)) {
                errors = errors || error{AllocatorRequired} || Allocator.Error;
            }

            for (info.fields) |field| {
                errors = errors || ParseInternalErrorImpl(field.field_type, inferred_set);
            }

            return errors;
        },
        .Pointer => |info| {
            var errors = error{ UnexpectedFieldType, Wat };

            if (isAllocatorRequired(T)) {
                errors = errors || error{AllocatorRequired} || Allocator.Error;
            }

            if (info.size == .Slice and info.child == u8 or info.child == json.Value)
                return errors;

            errors = errors || ParseInternalErrorImpl(info.child, inferred_set);

            return errors;
        },
        .Array => |info| {
            var errors = error{UnexpectedFieldType};

            errors = errors || ParseInternalErrorImpl(info.child, inferred_set);

            return errors;
        },
        .Vector => |info| {
            var errors = error{UnexpectedFieldType};

            errors = errors || ParseInternalErrorImpl(info.child, inferred_set);

            return errors;
        },

        else => return error{},
    }
}

pub fn isAllocatorRequired(comptime T: type) bool {
    // `inferred_types` is used to avoid infinite recursion for recursive type definitions.
    const inferred_types = [_]type{};
    return isAllocatorRequiredImpl(T, &inferred_types);
}

fn isAllocatorRequiredImpl(comptime T: type, comptime inferred_types: []const type) bool {
    for (inferred_types) |ty| {
        if (T == ty) return false;
    }

    const inferred_set = inferred_types ++ [_]type{T};

    switch (@typeInfo(T)) {
        .Optional => |info| return isAllocatorRequiredImpl(info.child, inferred_set),
        .Union => |info| {
            for (info.fields) |field| {
                if (isAllocatorRequiredImpl(field.field_type, inferred_set))
                    return true;
            }
        },
        .Struct => |info| {
            if (isArrayList(T)) {
                if (T == json.Array)
                    return false;

                return true;
            }

            if (isHashMap(T)) {
                if (T == json.ObjectMap)
                    return false;

                return true;
            }

            for (info.fields) |field| {
                if (@typeInfo(field.field_type) == .Struct and @hasDecl(field.field_type, "__json_is_undefinedable")) {
                    if (isAllocatorRequiredImpl(field.field_type.__json_T, inferred_set))
                        return true;
                } else if (isAllocatorRequiredImpl(field.field_type, inferred_set))
                    return true;
            }
        },
        .Pointer => |info| {
            if (info.size == .Slice and info.child == u8 or info.child == json.Value)
                return false;

            return true;
        },
        .Array => |info| {
            return isAllocatorRequiredImpl(info.child, inferred_set);
        },
        .Vector => |info| {
            return isAllocatorRequiredImpl(info.child, inferred_set); // is it even possible for this to be true?
        },
        else => {},
    }

    return false;
}

const logger = std.log.scoped(.json);
fn parseInternal(
    comptime T: type,
    comptime parent_name: []const u8,
    comptime field_name: []const u8,
    json_value: json.Value,
    maybe_allocator: ?Allocator,
    comptime suppress_error_logs: bool,
) ParseInternalError(T)!T {
    // TODO: Revert name fixes when stage2 comes out
    // and properly memoizes comptime strings
    const name = parent_name ++ "." ++ field_name;

    if (T == json.Value) return json_value;
    if (comptime meta.trait.isContainer(T) and @hasDecl(T, "tresParse")) {
        return T.tresParse(json_value, maybe_allocator);
    }

    switch (@typeInfo(T)) {
        .Bool => {
            if (json_value == .Bool) {
                return json_value.Bool;
            } else {
                if (comptime !suppress_error_logs) logger.debug("expected Bool, found {s} at {s}", .{ @tagName(json_value), name });

                return error.UnexpectedFieldType;
            }
        },
        .Float => {
            if (json_value == .Float) {
                return @floatCast(T, json_value.Float);
            } else if (json_value == .Integer) {
                return @intToFloat(T, json_value.Integer);
            } else {
                if (comptime !suppress_error_logs) logger.debug("expected Float, found {s} at {s}", .{ @tagName(json_value), name });

                return error.UnexpectedFieldType;
            }
        },
        .Int => {
            if (json_value == .Integer) {
                return math.cast(T, json_value.Integer) orelse return error.Overflow;
            } else {
                if (comptime !suppress_error_logs) logger.debug("expected Integer, found {s} at {s}", .{ @tagName(json_value), name });

                return error.UnexpectedFieldType;
            }
        },
        .Optional => |info| {
            if (json_value == .Null) {
                return null;
            } else {
                return try parseInternal(
                    info.child,
                    @typeName(T),
                    "?",
                    json_value,
                    maybe_allocator,
                    suppress_error_logs,
                );
            }
        },
        .Enum => {
            if (json_value == .Integer) {
                // we use this to convert signed to unsigned and check if it actually fits.
                const tag = math.cast(@typeInfo(T).Enum.tag_type, json_value.Integer) orelse {
                    if (comptime !suppress_error_logs) logger.debug("invalid enum tag for {s}, found {d} at {s}", .{ @typeName(T), json_value.Integer, name });

                    return error.InvalidEnumTag;
                };

                return try meta.intToEnum(T, tag);
            } else if (json_value == .String) {
                return meta.stringToEnum(T, json_value.String) orelse {
                    if (comptime !suppress_error_logs) logger.debug("invalid enum tag for {s}, found '{s}' at {s}", .{ @typeName(T), json_value.String, name });

                    return error.InvalidEnumTag;
                };
            } else {
                if (comptime !suppress_error_logs) logger.debug("expected Integer or String, found {s} at {s}", .{ @tagName(json_value), name });

                return error.UnexpectedFieldType;
            }
        },
        .Union => |info| {
            if (info.tag_type != null) {
                inline for (info.fields) |field| {
                    if (parseInternal(
                        field.field_type,
                        @typeName(T),
                        field.name,
                        json_value,
                        maybe_allocator,
                        true,
                    )) |parsed_value| {
                        return @unionInit(T, field.name, parsed_value);
                    } else |_| {}
                }

                if (comptime !suppress_error_logs) logger.debug("union fell through for {s}, found {s} at {s}", .{ @typeName(T), @tagName(json_value), name });

                return error.UnexpectedFieldType;
            } else {
                @compileError("cannot parse an untagged union: " ++ @typeName(T));
            }
        },
        .Struct => |info| {
            if (comptime isArrayList(T)) {
                const Child = @typeInfo(T.Slice).Pointer.child;

                if (json_value == .Array) {
                    if (T == json.Array) return json_value.Array;

                    const allocator = maybe_allocator orelse return error.AllocatorRequired;

                    var array_list = try T.initCapacity(allocator, json_value.Array.capacity);

                    for (json_value.Array.items) |item| {
                        const parsed_value = try parseInternal(
                            Child,
                            @typeName(T),
                            ".(arraylist item)",
                            item,
                            maybe_allocator,
                            suppress_error_logs,
                        );

                        array_list.appendAssumeCapacity(parsed_value);
                    }

                    return array_list;
                } else {
                    if (comptime !suppress_error_logs) logger.debug("expected array of {s} at {s}, found {s}", .{ @typeName(Child), name, @tagName(json_value) });
                    return error.UnexpectedFieldType;
                }
            }

            if (comptime isHashMap(T)) {
                const Key = meta.fieldInfo(T.KV, .key).field_type;
                const Value = meta.fieldInfo(T.KV, .value).field_type;

                if (Key != []const u8) @compileError("HashMap key must be of type []const u8!");

                if (json_value == .Object) {
                    if (T == json.ObjectMap) return json_value.Object;

                    const allocator = maybe_allocator orelse return error.AllocatorRequired;

                    var map = if (comptime isManaged(T)) T.init(allocator) else T{};
                    var map_iterator = json_value.Object.iterator();

                    while (map_iterator.next()) |entry| {
                        const parsed_value = try parseInternal(
                            Value,
                            @typeName(T),
                            ".(hashmap entry)",
                            entry.value_ptr.*,
                            maybe_allocator,
                            suppress_error_logs,
                        );

                        if (comptime isManaged(T)) {
                            try map.put(entry.key_ptr.*, parsed_value);
                        } else {
                            try map.put(allocator, entry.key_ptr.*, parsed_value);
                        }
                    }

                    return map;
                } else {
                    if (comptime !suppress_error_logs) logger.debug("expected map of {s} at {s}, found {s}", .{ @typeName(Value), name, @tagName(json_value) });
                    return error.UnexpectedFieldType;
                }
            }

            if (info.is_tuple) {
                if (json_value != .Array) {
                    if (comptime !suppress_error_logs) logger.debug("expected Array, found {s} at {s}", .{ @tagName(json_value), name });
                    return error.UnexpectedFieldType;
                }

                const fields = @typeInfo(T).Struct.fields;

                if (json_value.Array.items.len != fields.len) {
                    if (comptime !suppress_error_logs) logger.debug("expected Array to match length of Tuple {s} but it doesn't; at {s}", .{ @typeName(T), name });
                    return error.UnexpectedFieldType;
                }

                var tuple: T = undefined;
                comptime var index: usize = 0;

                inline while (index < fields.len) : (index += 1) {
                    tuple[index] = try parseInternal(
                        fields[index].field_type,
                        @typeName(T),
                        comptime fmt.comptimePrint("[{d}]", .{index}),
                        json_value.Array.items[index],
                        maybe_allocator,
                        suppress_error_logs,
                    );
                }

                return tuple;
            }

            if (json_value == .Object) {
                var result: T = undefined;

                // Must use in order to bypass [#2727](https://github.com/ziglang/zig/issues/2727) :(
                var missing_field = false;

                inline for (info.fields) |field| {
                    const field_value = json_value.Object.get(field.name);

                    if (field.is_comptime) {
                        if (field_value == null) {
                            if (comptime !suppress_error_logs) logger.debug("comptime field {s}.{s} missing, at {s}", .{ @typeName(T), field.name, name });

                            return error.InvalidFieldValue;
                        }

                        if (field.default_value) |default| {
                            const parsed_value = try parseInternal(
                                field.field_type,
                                @typeName(T),
                                field.name,
                                field_value.?,
                                maybe_allocator,
                                suppress_error_logs,
                            );

                            const default_value = @ptrCast(
                                *const field.field_type,
                                @alignCast(@alignOf(field.field_type), default),
                            ).*;

                            const is_correct = if (field.field_type == []const u8 or field.field_type == []u8)
                                mem.eql(u8, parsed_value, default_value)
                            else
                                meta.eql(u8, parsed_value, default_value);

                            if (!is_correct) {
                                if (comptime !suppress_error_logs) logger.debug("comptime field {s}.{s} does not match", .{ @typeName(T), field.name });

                                return error.InvalidFieldValue;
                            }
                        } else unreachable; // zig requires comptime fields to have a default initialization value
                    } else {
                        if (field_value) |fv| {
                            if (@typeInfo(field.field_type) == .Struct and @hasDecl(field.field_type, "__json_is_undefinedable"))
                                @field(result, field.name) = .{
                                    .value = try parseInternal(
                                        field.field_type.__json_T,
                                        @typeName(T),
                                        field.name,
                                        fv,
                                        maybe_allocator,
                                        suppress_error_logs,
                                    ),
                                    .missing = false,
                                }
                            else
                                @field(result, field.name) = try parseInternal(
                                    field.field_type,
                                    @typeName(T),
                                    field.name,
                                    fv,
                                    maybe_allocator,
                                    suppress_error_logs,
                                );
                        } else {
                            if (@typeInfo(field.field_type) == .Struct and @hasDecl(field.field_type, "__json_is_undefinedable")) {
                                @field(result, field.name) = .{
                                    .value = undefined,
                                    .missing = true,
                                };
                            } else if (field.default_value) |default| {
                                const default_value = @ptrCast(
                                    *const field.field_type,
                                    @alignCast(@alignOf(field.field_type), default),
                                ).*;
                                @field(result, field.name) = default_value;
                            } else {
                                if (comptime !suppress_error_logs) logger.debug("required field {s}.{s} missing, at {s}", .{ @typeName(T), field.name, name });

                                missing_field = true;
                            }
                        }
                    }
                }

                if (missing_field) return error.MissingRequiredField;

                return result;
            } else {
                if (comptime !suppress_error_logs) logger.debug("expected Object, found {s} at {s}", .{ @tagName(json_value), name });

                return error.UnexpectedFieldType;
            }
        },
        .Pointer => |info| {
            if (info.size == .Slice) {
                if (info.child == u8) {
                    if (json_value == .String) {
                        return json_value.String;
                    } else {
                        if (comptime !suppress_error_logs) logger.debug("expected String, found {s} at {s}", .{ @tagName(json_value), name });

                        return error.UnexpectedFieldType;
                    }
                } else if (info.child == json.Value) {
                    return json_value.Array.items;
                }
            }

            const allocator = maybe_allocator orelse return error.AllocatorRequired;
            switch (info.size) {
                .Slice, .Many => {
                    const sentinel: ?info.child = if (info.sentinel) |ptr|
                        @ptrCast(
                            *const info.child,
                            @alignCast(@alignOf(info.child), ptr),
                        ).*
                    else
                        null;

                    if (info.child == u8 and json_value == .String) {
                        const array = try allocator.allocWithOptions(
                            info.child,
                            json_value.String.len,
                            info.alignment,
                            comptime sentinel,
                        );

                        mem.copy(u8, array, json_value.String);

                        return @ptrCast(T, array);
                    }

                    if (json_value == .Array) {
                        if (info.child == json.Value) return json_value.Array.items;

                        const array = try allocator.allocWithOptions(
                            info.child,
                            json_value.Array.items.len,
                            info.alignment,
                            comptime sentinel,
                        );

                        for (json_value.Array.items) |item, index|
                            array[index] = try parseInternal(
                                info.child,
                                @typeName(T),
                                "[...]",
                                item,
                                maybe_allocator,
                                suppress_error_logs,
                            );

                        return @ptrCast(T, array);
                    } else {
                        if (comptime !suppress_error_logs) logger.debug("expected Array, found {s} at {s}", .{ @tagName(json_value), name });

                        return error.UnexpectedFieldType;
                    }
                },
                .One, .C => {
                    if (comptime info.child == anyopaque) return error.Wat;
                    const data = try allocator.allocWithOptions(info.child, 1, info.alignment, null);

                    data[0] = try parseInternal(
                        info.child,
                        @typeName(T),
                        "*",
                        json_value,
                        maybe_allocator,
                        suppress_error_logs,
                    );

                    return &data[0];
                },
            }
        },
        .Array => |info| {
            if (json_value == .Array) {
                var array: T = undefined;

                if (info.sentinel) |ptr| {
                    const sentinel = @ptrCast(*const info.child, ptr).*;

                    array[array.len] = sentinel;
                }

                if (json_value.Array.items.len != info.len) {
                    if (comptime !suppress_error_logs) logger.debug("expected Array to match length of {s} but it doesn't; at {s}", .{ @typeName(T), name });
                    return error.UnexpectedFieldType;
                }

                for (array) |*item, index|
                    item.* = try parseInternal(
                        info.child,
                        @typeName(T),
                        "[...]",
                        json_value.Array.items[index],
                        maybe_allocator,
                        suppress_error_logs,
                    );

                return array;
            } else {
                if (comptime !suppress_error_logs) logger.debug("expected Array, found {s} at {s}", .{ @tagName(json_value), name });

                return error.UnexpectedFieldType;
            }
        },
        .Vector => |info| {
            if (json_value == .Array) {
                var vector: T = undefined;

                if (json_value.Array.items.len != info.len) {
                    if (comptime !suppress_error_logs) logger.debug("expected Array to match length of {s} ({d}) but it doesn't; at {s}", .{ @typeName(T), info.len, name });
                    return error.UnexpectedFieldType;
                }

                for (vector) |*item|
                    item.* = try parseInternal(
                        info.child,
                        @typeName(T),
                        "[...]",
                        item,
                        maybe_allocator,
                        suppress_error_logs,
                    );

                return vector;
            } else {
                if (comptime !suppress_error_logs) logger.debug("expected Array, found {s} at {s}", .{ @tagName(json_value), name });

                return error.UnexpectedFieldType;
            }
        },
        else => {
            @compileError("unhandled json type: " ++ @typeName(T) ++ " at " ++ name);
        },
    }
}

fn outputUnicodeEscape(
    codepoint: u21,
    out_stream: anytype,
) !void {
    if (codepoint <= 0xFFFF) {
        // If the character is in the Basic Multilingual Plane (U+0000 through U+FFFF),
        // then it may be represented as a six-character sequence: a reverse solidus, followed
        // by the lowercase letter u, followed by four hexadecimal digits that encode the character's code point.
        try out_stream.writeAll("\\u");
        try fmt.formatIntValue(codepoint, "x", fmt.FormatOptions{ .width = 4, .fill = '0' }, out_stream);
    } else {
        assert(codepoint <= 0x10FFFF);
        // To escape an extended character that is not in the Basic Multilingual Plane,
        // the character is represented as a 12-character sequence, encoding the UTF-16 surrogate pair.
        const high = @intCast(u16, (codepoint - 0x10000) >> 10) + 0xD800;
        const low = @intCast(u16, codepoint & 0x3FF) + 0xDC00;
        try out_stream.writeAll("\\u");
        try fmt.formatIntValue(high, "x", fmt.FormatOptions{ .width = 4, .fill = '0' }, out_stream);
        try out_stream.writeAll("\\u");
        try fmt.formatIntValue(low, "x", fmt.FormatOptions{ .width = 4, .fill = '0' }, out_stream);
    }
}

fn outputJsonString(value: []const u8, options: json.StringifyOptions, out_stream: anytype) !void {
    try out_stream.writeByte('\"');
    var i: usize = 0;
    while (i < value.len) : (i += 1) {
        switch (value[i]) {
            // normal ascii character
            0x20...0x21, 0x23...0x2E, 0x30...0x5B, 0x5D...0x7F => |c| try out_stream.writeByte(c),
            // only 2 characters that *must* be escaped
            '\\' => try out_stream.writeAll("\\\\"),
            '\"' => try out_stream.writeAll("\\\""),
            // solidus is optional to escape
            '/' => {
                if (options.string.String.escape_solidus) {
                    try out_stream.writeAll("\\/");
                } else {
                    try out_stream.writeByte('/');
                }
            },
            // control characters with short escapes
            // TODO: option to switch between unicode and 'short' forms?
            0x8 => try out_stream.writeAll("\\b"),
            0xC => try out_stream.writeAll("\\f"),
            '\n' => try out_stream.writeAll("\\n"),
            '\r' => try out_stream.writeAll("\\r"),
            '\t' => try out_stream.writeAll("\\t"),
            else => {
                const ulen = unicode.utf8ByteSequenceLength(value[i]) catch unreachable;
                // control characters (only things left with 1 byte length) should always be printed as unicode escapes
                if (ulen == 1 or options.string.String.escape_unicode) {
                    const codepoint = unicode.utf8Decode(value[i .. i + ulen]) catch unreachable;
                    try outputUnicodeEscape(codepoint, out_stream);
                } else {
                    try out_stream.writeAll(value[i .. i + ulen]);
                }
                i += ulen - 1;
            },
        }
    }
    try out_stream.writeByte('\"');
}

pub fn stringify(
    value: anytype,
    options: json.StringifyOptions,
    out_stream: anytype,
) @TypeOf(out_stream).Error!void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .Float, .ComptimeFloat => {
            return fmt.formatFloatScientific(value, fmt.FormatOptions{}, out_stream);
        },
        .Int, .ComptimeInt => {
            return fmt.formatIntValue(value, "", fmt.FormatOptions{}, out_stream);
        },
        .Bool => {
            return out_stream.writeAll(if (value) "true" else "false");
        },
        .Null => {
            return out_stream.writeAll("null");
        },
        .Optional => {
            if (value) |payload| {
                return try stringify(payload, options, out_stream);
            } else {
                return try stringify(null, options, out_stream);
            }
        },
        .Enum => {
            if (comptime meta.trait.hasFn("jsonStringify")(T)) {
                return value.jsonStringify(options, out_stream);
            }

            @compileError("Unable to stringify enum '" ++ @typeName(T) ++ "'");
        },
        .Union => {
            if (comptime meta.trait.hasFn("jsonStringify")(T)) {
                return value.jsonStringify(options, out_stream);
            }

            const info = @typeInfo(T).Union;
            if (info.tag_type) |UnionTagType| {
                inline for (info.fields) |u_field| {
                    if (value == @field(UnionTagType, u_field.name)) {
                        return try stringify(@field(value, u_field.name), options, out_stream);
                    }
                }
            } else {
                @compileError("Unable to stringify untagged union '" ++ @typeName(T) ++ "'");
            }
        },
        .Struct => |S| {
            if (comptime isArrayList(T)) {
                return stringify(value.items, options, out_stream);
            }

            if (comptime isHashMap(T)) {
                var iterator = value.iterator();
                var first = true;

                try out_stream.writeByte('{');
                while (iterator.next()) |entry| {
                    if (!first) {
                        try out_stream.writeByte(',');
                    } else first = false;
                    try stringify(entry.key_ptr.*, options, out_stream);
                    try out_stream.writeByte(':');
                    try stringify(entry.value_ptr.*, options, out_stream);
                }
                try out_stream.writeByte('}');

                return;
            }

            if (comptime meta.trait.hasFn("jsonStringify")(T)) {
                return value.jsonStringify(options, out_stream);
            }

            try out_stream.writeByte('{');
            var field_output = false;
            var child_options = options;
            if (child_options.whitespace) |*child_whitespace| {
                child_whitespace.indent_level += 1;
            }
            inline for (S.fields) |Field| {
                // don't include void fields
                if (Field.field_type == void) continue;

                var emit_field = true;

                // don't include optional fields that are null when emit_null_optional_fields is set to false
                if (@typeInfo(Field.field_type) == .Optional) {
                    if (options.emit_null_optional_fields == false) {
                        if (@field(value, Field.name) == null) {
                            emit_field = false;
                        }
                    }
                }

                const is_undefinedable = comptime @typeInfo(@TypeOf(@field(value, Field.name))) == .Struct and @hasDecl(@TypeOf(@field(value, Field.name)), "__json_is_undefinedable");
                if (is_undefinedable) {
                    if (@field(value, Field.name).missing)
                        emit_field = false;
                }

                if (emit_field) {
                    if (!field_output) {
                        field_output = true;
                    } else {
                        try out_stream.writeByte(',');
                    }
                    if (child_options.whitespace) |child_whitespace| {
                        try out_stream.writeByte('\n');
                        try child_whitespace.outputIndent(out_stream);
                    }
                    try outputJsonString(Field.name, options, out_stream);
                    try out_stream.writeByte(':');
                    if (child_options.whitespace) |child_whitespace| {
                        if (child_whitespace.separator) {
                            try out_stream.writeByte(' ');
                        }
                    }
                    try stringify(if (is_undefinedable)
                        @field(value, Field.name).value
                    else
                        @field(value, Field.name), child_options, out_stream);
                }
            }
            if (field_output) {
                if (options.whitespace) |whitespace| {
                    try out_stream.writeByte('\n');
                    try whitespace.outputIndent(out_stream);
                }
            }
            try out_stream.writeByte('}');
            return;
        },
        .ErrorSet => return stringify(@as([]const u8, @errorName(value)), options, out_stream),
        .Pointer => |ptr_info| switch (ptr_info.size) {
            .One => switch (@typeInfo(ptr_info.child)) {
                .Array => {
                    const Child = @typeInfo(ptr_info.child).Array.child;
                    const Slice = []const Child;
                    return stringify(@as(Slice, value), options, out_stream);
                },
                else => {
                    // TODO: avoid loops?
                    return stringify(value.*, options, out_stream);
                },
            },
            // TODO: .Many when there is a sentinel (waiting for https://github.com/ziglang/zig/pull/3972)
            .Slice => {
                if (ptr_info.child == u8 and options.string == .String and unicode.utf8ValidateSlice(value)) {
                    try outputJsonString(value, options, out_stream);
                    return;
                }

                try out_stream.writeByte('[');
                var child_options = options;
                if (child_options.whitespace) |*whitespace| {
                    whitespace.indent_level += 1;
                }
                for (value) |x, i| {
                    if (i != 0) {
                        try out_stream.writeByte(',');
                    }
                    if (child_options.whitespace) |child_whitespace| {
                        try out_stream.writeByte('\n');
                        try child_whitespace.outputIndent(out_stream);
                    }
                    try stringify(x, child_options, out_stream);
                }
                if (value.len != 0) {
                    if (options.whitespace) |whitespace| {
                        try out_stream.writeByte('\n');
                        try whitespace.outputIndent(out_stream);
                    }
                }
                try out_stream.writeByte(']');
                return;
            },
            else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
        },
        .Array => return stringify(&value, options, out_stream),
        .Vector => |info| {
            const array: [info.len]info.child = value;
            return stringify(&array, options, out_stream);
        },
        else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
    }
    unreachable;
}

test "json.parse simple struct" {
    @setEvalBranchQuota(10_000);

    const Role = enum(i64) { crewmate, impostor, ghost };

    const Union = union(enum) {
        a: i64,
        b: []const u8,
    };

    const Substruct = struct {
        value: json.Value,
        slice_of_values: []json.Value,

        union_a: Union,
        union_b: Union,
    };

    const Player = struct {
        name: []const u8,
        based: bool,
    };

    const MyTuple = meta.Tuple(&[_]type{ i64, bool });

    const Struct = struct {
        bool_true: bool,
        bool_false: bool,
        integer: u8,
        float: f64,
        optional: ?f32,
        an_enum: Role,
        an_enum_string: Role,
        slice: []i64,
        substruct: Substruct,

        random_map: json.ObjectMap,
        number_map: std.StringArrayHashMap(i64),
        players: std.StringHashMap(Player),
        players_unmanaged: std.StringHashMapUnmanaged(Player),

        my_tuple: MyTuple,
        my_array: [2]u8,
        my_array_of_any: [2]json.Value,
        my_array_list: std.ArrayList(i64),
        my_array_list_of_any: json.Array,

        a_pointer: *u8,
        a_weird_string: [*:0]u8,
    };

    const data =
        \\{
        \\    "bool_true": true,
        \\    "bool_false": false,
        \\    "integer": 100,
        \\    "float": 4.2069,
        \\    "optional": null,
        \\    "an_enum": 1,
        \\    "an_enum_string": "crewmate",
        \\    "slice": [1, 2, 3, 4, 5, 6],
        \\    "substruct": {
        \\        "value": "hello",
        \\        "slice_of_values": ["hello", "world"],
        \\        "union_a": -42,
        \\        "union_b": "hello"
        \\    },
        \\    "random_map": {
        \\        "a": 123,
        \\        "b": "Amogus!!"
        \\    },
        \\    "number_map": {
        \\        "a": 123,
        \\        "b": 456
        \\    },
        \\    "players": {
        \\        "aurame": {"name": "Auguste", "based": true},
        \\        "mattnite": {"name": "Matt", "based": true}
        \\    },
        \\    "players_unmanaged": {
        \\        "aurame": {"name": "Auguste", "based": true},
        \\        "mattnite": {"name": "Matt", "based": true}
        \\    },
        \\    "my_tuple": [10, false],
        \\    "my_array": [1, 255],
        \\    "my_array_of_any": ["a", 2],
        \\    "my_array_list": [2, 254],
        \\    "my_array_list_of_any": ["b", 3],
        \\    "a_pointer": 5,
        \\    "a_weird_string": "hello"
        \\}
    ;

    // NOTE: In practice, we're going to use an arena, thus no parseFree exists because it is not required :)
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var testing_parser = json.Parser.init(arena.allocator(), false);
    const tree = try testing_parser.parse(data);

    const parsed = try parse(Struct, tree.root, arena.allocator());

    try testing.expectEqual(true, parsed.bool_true);
    try testing.expectEqual(false, parsed.bool_false);
    try testing.expectEqual(@as(u8, 100), parsed.integer);
    try testing.expectApproxEqRel(@as(f64, 4.2069), parsed.float, math.epsilon(f64));
    try testing.expectEqual(@as(?f32, null), parsed.optional);
    try testing.expectEqual(Role.impostor, parsed.an_enum);
    try testing.expectEqual(Role.crewmate, parsed.an_enum_string);
    try testing.expectEqualSlices(i64, &[_]i64{ 1, 2, 3, 4, 5, 6 }, parsed.slice);

    try testing.expect(parsed.substruct.value == .String);
    try testing.expectEqualStrings("hello", parsed.substruct.value.String);
    try testing.expect(parsed.substruct.slice_of_values.len == 2);
    try testing.expect(parsed.substruct.slice_of_values[0] == .String);
    try testing.expectEqualStrings("hello", parsed.substruct.slice_of_values[0].String);
    try testing.expect(parsed.substruct.slice_of_values[1] == .String);
    try testing.expectEqualStrings("world", parsed.substruct.slice_of_values[1].String);
    try testing.expect(parsed.substruct.union_a == .a);
    try testing.expectEqual(@as(i64, -42), parsed.substruct.union_a.a);
    try testing.expect(parsed.substruct.union_b == .b);
    try testing.expectEqualStrings("hello", parsed.substruct.union_b.b);

    try testing.expectEqual(@as(i64, 123), parsed.random_map.get("a").?.Integer);
    try testing.expectEqualStrings("Amogus!!", parsed.random_map.get("b").?.String);

    try testing.expectEqual(@as(i64, 123), parsed.number_map.get("a").?);
    try testing.expectEqual(@as(i64, 456), parsed.number_map.get("b").?);

    try testing.expectEqualStrings("Auguste", parsed.players.get("aurame").?.name);
    try testing.expectEqualStrings("Matt", parsed.players.get("mattnite").?.name);
    try testing.expectEqual(true, parsed.players.get("aurame").?.based);
    try testing.expectEqual(true, parsed.players.get("mattnite").?.based);

    try testing.expectEqualStrings("Auguste", parsed.players_unmanaged.get("aurame").?.name);
    try testing.expectEqualStrings("Matt", parsed.players_unmanaged.get("mattnite").?.name);
    try testing.expectEqual(true, parsed.players_unmanaged.get("aurame").?.based);
    try testing.expectEqual(true, parsed.players_unmanaged.get("mattnite").?.based);

    try testing.expectEqual(MyTuple{ 10, false }, parsed.my_tuple);

    try testing.expectEqual([2]u8{ 1, 255 }, parsed.my_array);

    try testing.expect(parsed.my_array_of_any[0] == .String);
    try testing.expectEqualStrings("a", parsed.my_array_of_any[0].String);
    try testing.expect(parsed.my_array_of_any[1] == .Integer);
    try testing.expectEqual(@as(i64, 2), parsed.my_array_of_any[1].Integer);

    try testing.expectEqual(@as(usize, 2), parsed.my_array_list.items.len);
    try testing.expectEqualSlices(i64, &[_]i64{ 2, 254 }, parsed.my_array_list.items);

    try testing.expectEqual(@as(usize, 2), parsed.my_array_list_of_any.items.len);
    try testing.expect(parsed.my_array_list_of_any.items[0] == .String);
    try testing.expectEqualStrings("b", parsed.my_array_list_of_any.items[0].String);
    try testing.expect(parsed.my_array_list_of_any.items[1] == .Integer);
    try testing.expectEqual(@as(i64, 3), parsed.my_array_list_of_any.items[1].Integer);

    try testing.expectEqual(@as(u8, 5), parsed.a_pointer.*);

    try testing.expectEqualStrings("hello", mem.sliceTo(parsed.a_weird_string, 0));
}

test "json.parse missing field" {
    const Struct = struct {
        my_super_duper_important_field: bool,
    };

    const data =
        \\{}
    ;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var testing_parser = json.Parser.init(arena.allocator(), false);
    const tree = try testing_parser.parse(data);

    const parsed = parse(Struct, tree.root, arena.allocator());

    try testing.expectError(error.MissingRequiredField, parsed);
}

test "json.parse undefinedable fields and default values" {
    const Struct = struct {
        meh: Undefinedable(i64),
        meh2: Undefinedable(i64),
        default: u8 = 123,
    };

    const data =
        \\{
        \\    "meh": 42069
        \\}
    ;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var testing_parser = json.Parser.init(arena.allocator(), false);
    const tree = try testing_parser.parse(data);

    const parsed = try parse(Struct, tree.root, arena.allocator());

    try testing.expectEqual(@as(i64, 42069), parsed.meh.value);
    try testing.expectEqual(true, parsed.meh2.missing);
    try testing.expectEqual(@as(u8, 123), parsed.default);
}

test "json.parse comptime fields" {
    const YoureTheImpostorMessage = struct {
        comptime method: []const u8 = "ship/impostor",
        sussiness: f64,
    };

    const YoureCuteUwUMessage = struct {
        comptime method: []const u8 = "a/cutiepie",
        cuteness: i64,
    };

    const Message = union(enum) {
        youre_the_impostor: YoureTheImpostorMessage,
        youre_cute_uwu: YoureCuteUwUMessage,
    };

    const first_message =
        \\{
        \\    "method": "ship/impostor",
        \\    "sussiness": 69.420
        \\}
    ;

    const second_message =
        \\{
        \\    "method": "a/cutiepie",
        \\    "cuteness": 100
        \\}
    ;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var testing_parser = json.Parser.init(arena.allocator(), false);

    const first_tree = try testing_parser.parse(first_message);
    const first_parsed = try parse(Message, first_tree.root, arena.allocator());

    try testing.expect(first_parsed == .youre_the_impostor);

    testing_parser.reset();

    const second_tree = try testing_parser.parse(second_message);
    const second_parsed = try parse(Message, second_tree.root, arena.allocator());

    try testing.expect(second_parsed == .youre_cute_uwu);
}

test "json.parse custom check functions for unions" {
    // jsonrpc request
    const RequestId = union(enum) { string: []const u8, integer: i64 };

    const AmogusRequest = struct {
        const method = "spaceship/amogus";

        sussy: bool,
    };

    const MinecraftNotification = struct {
        const method = "game/minecraft";

        crafted: i64,
        mined: i64,
    };

    const RequestParams = union(enum) {
        amogus: AmogusRequest,
        minecraft: MinecraftNotification,
    };

    const RequestOrNotification = struct {
        const Self = @This();

        jsonrpc: []const u8,
        id: ?RequestId = null,
        method: []const u8,
        params: RequestParams,

        fn RequestOrNotificationParseError() type {
            var err = ParseInternalError(RequestId);
            inline for (meta.fields(RequestParams)) |field| {
                err = err || ParseInternalError(field.field_type);
            }
            return err;
        }

        pub fn tresParse(value: json.Value, allocator: ?Allocator) RequestOrNotificationParseError()!Self {
            // var allocator = options.allocator orelse return error.AllocatorRequired;
            var object = value.Object;
            var request_or_notif: Self = undefined;

            request_or_notif.jsonrpc = object.get("jsonrpc").?.String;
            request_or_notif.id = if (object.get("id")) |id| try parse(RequestId, id, allocator) else null;
            request_or_notif.method = object.get("method").?.String;

            inline for (meta.fields(RequestParams)) |field| {
                if (mem.eql(u8, request_or_notif.method, field.field_type.method)) {
                    request_or_notif.params = @unionInit(RequestParams, field.name, try parse(field.field_type, object.get("params").?, allocator));
                }
            }

            return request_or_notif;
        }
    };

    const first_message =
        \\{
        \\    "jsonrpc": "2.0",
        \\    "id": 10,
        \\    "method": "spaceship/amogus",
        \\    "params": {"sussy": true}
        \\}
    ;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var testing_parser = json.Parser.init(arena.allocator(), false);
    const first_tree = try testing_parser.parse(first_message);
    const first_parsed = try parse(RequestOrNotification, first_tree.root, arena.allocator());

    try testing.expectEqualStrings("2.0", first_parsed.jsonrpc);
    try testing.expect(first_parsed.id != null);
    try testing.expect(first_parsed.id.? == .integer);
    try testing.expectEqual(@as(i64, 10), first_parsed.id.?.integer);
    try testing.expectEqualStrings("spaceship/amogus", first_parsed.method);
    try testing.expect(first_parsed.params == .amogus);
    try testing.expectEqual(true, first_parsed.params.amogus.sussy);

    // TODO: Add second test
}

test "json.parse allocator required errors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var testing_parser = json.Parser.init(arena.allocator(), false);

    try testing.expectError(error.AllocatorRequired, parse([]i64, (try testing_parser.parse("[1, 2, 3, 4]")).root, null));
    testing_parser.reset();
    try testing.expectError(error.AllocatorRequired, parse(std.StringArrayHashMap(i64), (try testing_parser.parse(
        \\{"a": 123, "b": -69}
    )).root, null));
}

test "json.stringify basics" {
    var stringify_buf: [28]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&stringify_buf);

    const Basic = struct {
        unsigned: u16,
        signed: i16,
    };

    var basic = Basic{
        .unsigned = 69,
        .signed = -69,
    };

    try stringify(basic, .{}, fbs.writer());

    try testing.expectEqualStrings(
        \\{"unsigned":69,"signed":-69}
    , &stringify_buf);
}

test "json.stringify undefinedables" {
    var furry_buf: [49]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&furry_buf);

    const Furry = struct {
        name: Undefinedable([]const u8),
        age: Undefinedable(i64),
        plays_amogus: bool,
        joe: Undefinedable([]const u8),
    };

    var rimu = Furry{
        .name = .{ .value = "Rimu", .missing = false },
        .age = .{ .value = undefined, .missing = true },
        .plays_amogus = false,
        .joe = .{ .value = "Mama", .missing = false },
    };

    try stringify(rimu, .{}, fbs.writer());

    try testing.expectEqualStrings(
        \\{"name":"Rimu","plays_amogus":false,"joe":"Mama"}
    , &furry_buf);
}

test "json.stringify arraylist" {
    var stringify_buf: [49]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&stringify_buf);

    const Database = struct {
        names_of_my_pals: std.ArrayList([]const u8),
    };

    var db = Database{
        .names_of_my_pals = std.ArrayList([]const u8).init(testing.allocator),
    };
    defer db.names_of_my_pals.deinit();

    try db.names_of_my_pals.append("Travis");
    try db.names_of_my_pals.append("Rimu");
    try db.names_of_my_pals.append("Flandere");

    try stringify(db, .{}, fbs.writer());

    try testing.expectEqualStrings(
        \\{"names_of_my_pals":["Travis","Rimu","Flandere"]}
    , &stringify_buf);
}

test "json.stringify hashmaps" {
    var stringify_buf: [51]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&stringify_buf);

    const Database = struct {
        coolness: std.StringHashMap(f64),
    };

    var db = Database{
        .coolness = std.StringHashMap(f64).init(testing.allocator),
    };
    defer db.coolness.deinit();

    try db.coolness.put("Montreal", -20);
    try db.coolness.put("Beirut", 20);

    try stringify(db, .{}, fbs.writer());

    try testing.expectEqualStrings(
        \\{"coolness":{"Montreal":-2.0e+01,"Beirut":2.0e+01}}
    , &stringify_buf);
}
