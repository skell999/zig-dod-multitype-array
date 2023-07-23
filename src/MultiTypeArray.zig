const std = @import("std");

// pub fn MTA() type {

//     types[]comps[]fields[]data[]

//     const T = struct {
//         t: type,
//         comp_ids: []usize,
//         ranges: []Range,
//     };

//     const Component = struct {
//         t: type,
//         id: usize,
//         fields: []u8, // data arrays
//     };

// }

// ADD T AND COMPONENTS AS SEPERATE LISTS (TUPLES)
pub fn MultiTypeArray(comptime typeTuple: anytype, comptime componentTuple: anytype) type {

    // const Field = struct {
    //     t: std.builtin.Type.Struct,
    //     field: std.builtin.Type.StructField
    // };

    // const Range = struct {
    //     begin: u32,
    //     end: u32,
    // };

    // const T = struct {
    //     t: std.builtin.Type.Struct,
    //     ranges: []Range,
    // };
    // _ = T;

    const fields = blk: {
        var fields: []const Field = &[_]Field{};
        inline for (typeTuple) |t| {
            inline for (std.meta.fields(t)) |f1| {
                var isInArray = false;
                if(fields.len == 0) { fields = fields ++ &[_]Field{ .{.t = @typeInfo(t).Struct, .field = f1} }; continue;}

                inline for (fields) |f2| {
                    if(std.mem.eql(u8, f1.name, f2.field.name) and (f1.type != f2.field.type)) {
                        @compileError("[Error] Field name match with field type mismatch. Ensure fields with same name have matching types");
                    }
                    
                    if(std.mem.eql(u8, f1.name, f2.field.name) and (f1.type == f2.field.type)) {
                        isInArray = true;
                        continue;
                    }
                }

                if(!isInArray) {
                    fields = fields ++ &[_]Field{ .{.t = @typeInfo(t).Struct, .field = f1} };
                }
            }
        }
        break :blk fields;
    };

    const numFields = fields.len;

// HAVE TO CREATE ARRAY OF T AND ARRAY OF COMPONENT

    const T = struct {
        t: type,
        comp_ids: []usize,
        begin: usize,
        end: usize,
    };

    const Component = struct {
        t: type,
        id: usize,
        fields: []u8, // data arrays
        // offset: []usize,
    };

// index plus offset VERSUS array of index offsets for each object
// faster lookup VERSUS faster contiguous array processing

// 2d virtual addressing

    // t_x is used to map a component virtual index to an object type
    // c_y is used to get the virtual offset for a component
    // types is an array of type info each index is the types id
    // comps holds an array of component info each index is the components id

    // Use cases

        // When iterating data arrays. Get the type id when you only have component index
            // Use the componets id to get virtual component offset in c_y
            // Use offset + data index to get the type id from t_x

        // Get uid from component data index
            // Use the componets id to get virtual component offset in c_y
            // Use offset + data index to get the type id from uid_x

        // Does uid have component
            // Option 1 
                // Encode comps in uid

            // Option 2
                // Encode type in uid <----- this one
            
            // Option 3
                // Comptime encode ids in uid by counting exact number of bits needed for id sizes

            // Option 4 
                // Store extra data in arrays

            // Option 5
                // Search sorted uid array for type id

        // Get uid's object id
            // 1
                // store obj id in lookup table, sorted by uid
            
            // 2
                // Keep objects sorted by uid when in data array
                // Then we only have binary search the objects x space to find obj id


    return struct {
        alloc: std.mem.Allocator,

        uid_sorted: []usize, // list of object uid's
// Could have a sorted list of uid's that map to types
// Could have a struct with type and uid fileds for quick lookup, sorted by uid
        types: []T,
        comps: []Component,

        uid_x: []usize, // for each index store its uid, can be used to get uid from comp index
        t_x: usize, // one entry for each entity space, each entry is a T id (this would map component index to T id)
        c_y: usize, // one entry for each component, each entry is an offset (this would map T index to comp id) (needs extra stuff cos not contiguous)

        // cache comp to types qeury
        // get all types with this comp
        typeHasComps: [comp_id][type_ids]usize,

        const Self = @This();
        var seed: [8]u8 = undefined;
        const _ = std.os.getrandom(seed);
        var rand: std.rand.Xoshiro256 = std.rand.DefaultPrng.init(@as(u64,@intFromPtr(seed.ptr)));

        pub fn init(alloc: std.mem.Allocator) !Self {
            return .{
                .alloc = alloc,
                .data = blk: { 
                    var data: [numFields][]u8 = undefined;
                    inline for(0..numFields) |i| {
                        data[i] = try alloc.alignedAlloc(u8, fields[i].field.alignment, 0);
                    }
                    break :blk data;
                },
                .uid = try alloc.alloc(usize, 0),
                .indices = try alloc.alloc([numFields]usize, 0),
            };
        }

        pub fn append(self: *Self, t: anytype) !void {
            _ = t;
            _ = self;

        }
        
        // pub fn resize(comptime t: type, data: []u8) ![]u8{

        // }
// Layout patterns
    // Fixed buffer
    // Shared Contiguous array
    // Seperate arrays

// Shuffle insertion removal

// Tree structures

        fn generate_uid() usize {
            return rand.random().int(usize);
        }

        pub fn get_index(comptime name: []const u8) usize {
            inline for(fields, 0..) |n,i| {
                if(std.mem.eql(u8, name, n.field.name)) {
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