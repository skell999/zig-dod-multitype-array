const std = @import("std");

pub fn MultiTypeArray(comptime typeTuple: anytype) type {

    // const numTypes = @typeInfo(@TypeOf(typeTuple)).Struct.fields.len;
    const fieldNames = blk: {
        var fields: []const std.builtin.Type.StructField = &[_]std.builtin.Type.StructField{};
        inline for (typeTuple) |t| {
            inline for (std.meta.fields(t)) |f1| {
                var isInArray = false;
                if(fields.len == 0) { fields = fields ++ &[_]std.builtin.Type.StructField{f1}; continue;}

                inline for (fields) |f2| {
                    if(std.mem.eql(u8, f1.name, f2.name) and (f1.type != f2.type)) {
                        @compileError("[Error] Field name match with field type mismatch. Ensure fields with same name have matching types");
                    }
                    
                    if(std.mem.eql(u8, f1.name, f2.name) and (f1.type == f2.type)) {
                        isInArray = true;
                        continue;
                    }
                }

                if(!isInArray) {
                    fields = fields ++ &[_]std.builtin.Type.StructField{f1};
                }
            }
        }
        break :blk fields;
    };
    const numFields = fieldNames.len;



    return struct {
        alloc: std.mem.Allocator,
        data: [numFields][]u8, // ptrs to data arrays
        uid: []usize, // list of object uid's
        indices: [][numFields]usize, // object data indices. perhaps group like objects in memory and store 1 offset for each object type. so for each type indices would start at zero + offset

        const Self = @This();
        var seed: [8]u8 = undefined;
        const _ = std.os.getrandom(seed);
        var rand: std.rand.Xoshiro256 = std.rand.DefaultPrng.init(@as(u64,@intFromPtr(seed.ptr)));

        pub fn init(alloc: std.mem.Allocator) !Self {
            return .{
                .alloc = alloc,
                .data = blk: { 
                    var data: [numFields][]u8 = undefined;
                    for(0..numFields) |i| {
                        data[i] = try alloc.alloc(u8, 0);
                    }
                    break :blk data;
                },
                .uid = try alloc.alloc(usize, 0),
                .indices = try alloc.alloc([numFields]usize, 0),
            };
        }

        pub fn append(self: *Self, t: anytype) !void {
            _ = self;
            // var indices: [numFields]usize = undefined;
            inline for(std.meta.fields(t)) |f| {
                var index = get_data_array(f.name);
                _ = index;

            }
        }
        
        // pub fn resize(comptime t: type, data: []u8) ![]u8{

        // }

        fn generate_uid() usize {
            return rand.random().int(usize);
        }

        pub fn get_data_array(comptime name: []const u8) usize {
            inline for(fieldNames, 0..) |n,i| {
                if(std.mem.eql(u8, name, n)) {
                    return i;
                }
            }
            @compileError("Field not found\n");
        }
    };
}
    // contiguos memory group, a user supplied integer id that ensues object with id are contiguous
    // user enabled creation of dead list and disabled lists
    // user supplied pre allocation sizes for groups
    // user creation of lookup indices for tagging
    // uuid for objects
test "MultiTypeArray" {
    var alloc = std.testing.allocator;
    const Goo = struct { first: u32 = 0, second: u32 = 0 };
    const Foo = struct { first: u32 = 0, second: u32 = 0, third: u32 };

    const MAL = MultiTypeArray(.{Goo,Foo});
    var instance = try MAL.init(alloc);
    _ = instance;
    var foo: u32 = 0;
    _ = foo;
}