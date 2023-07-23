const std = @import("std");
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


// // Cast byte slices to another slice type

// 	std.mem.bytesAsSlice(); // line 3589
// 	/// Given a slice of bytes, returns a slice of the specified type
// 	/// backed by those bytes, preserving pointer attributes.
// 		pub fn bytesAsSlice(comptime T: type, bytes: anytype)

// // Cast slice to slice of bytes
// 	std.mem.sliceAsBytes();
// 	/// Given a slice, returns a slice of the underlying bytes, preserving pointer attributes.
// 	pub fn sliceAsBytes(slice: anytype)

// /// Given a pointer to an array of bytes, returns a pointer to a value of the specified type
// /// backed by those bytes, preserving pointer attributes.
// 	std.mem.bytesAsValue();
// 	pub fn bytesAsValue(comptime T: type, bytes: anytype) BytesAsValueReturnType(T, @TypeOf(bytes)) {
// 	    return @ptrCast(BytesAsValueReturnType(T, @TypeOf(bytes)), bytes);
// 	}

// /// Given a pointer to an array of bytes, returns a value of the specified type backed by a
// /// copy of those bytes.
// 	std.mem.bytesToValue();
// 	pub fn bytesToValue(comptime T: type, bytes: anytype) T {
// 	    return bytesAsValue(T, bytes).*;
// 	}


pub fn MultiTypeArray(comptime typeTuple: anytype, comptime componentTuple: anytype) type {

    // const fields = blk: {
    //     var fields: []const Field = &[_]Field{};
    //     inline for (typeTuple) |t| {
    //         inline for (std.meta.fields(t)) |f1| {
    //             var isInArray = false;
    //             if(fields.len == 0) { fields = fields ++ &[_]Field{ .{.t = @typeInfo(t).Struct, .field = f1} }; continue;}

    //             inline for (fields) |f2| {
    //                 if(std.mem.eql(u8, f1.name, f2.field.name) and (f1.type != f2.field.type)) {
    //                     @compileError("[Error] Field name match with field type mismatch. Ensure fields with same name have matching types");
    //                 }
                    
    //                 if(std.mem.eql(u8, f1.name, f2.field.name) and (f1.type == f2.field.type)) {
    //                     isInArray = true;
    //                     continue;
    //                 }
    //             }

    //             if(!isInArray) {
    //                 fields = fields ++ &[_]Field{ .{.t = @typeInfo(t).Struct, .field = f1} };
    //             }
    //         }
    //     }
    //     break :blk fields;
    // };
    // const numFields = fields.len;

    const T = struct {
        comp_ids: std.ArrayList(usize),
        begin: usize,
        size: usize,
    };

    const Component = struct {
        fields: []*u8, // data arrays
        len: usize = 0,
        // fields: [*]anyopaque, // data arrays
        // fields: []*anyopaque, // data arrays
    };
    _ = Component;

    const numTypes = @typeInfo(@TypeOf(typeTuple)).Struct.fields.len;
    const numComps = @typeInfo(@TypeOf(componentTuple)).Struct.fileds.len;
    _ = numComps;

    return struct {
        alloc: std.mem.Allocator,
        //uid_sorted: []usize, // list of object uid's. Could have a sorted list of uid's that map to types. Could have a struct with type and uid fileds for quick lookup, sorted by uid
        types: [numTypes]T,
        comps: [numComps]Component,
        //uid_x: []usize, // for each index store its uid, can be used to get uid from comp index
        //t_x: usize, // one entry for each entity space, each entry is a T id (this would map component index to T id)
        //c_y: usize, // one entry for each component, each entry is an offset (this would map T index to comp id) (needs extra stuff cos not contiguous)

        // cache comp to types query
            // get all types with this comp
            //typeHasComps: [comp_id][type_ids]usize,

        const Self = @This();
        var seed: [8]u8 = undefined;
        const _ = std.os.getrandom(seed);
        var rand: std.rand.Xoshiro256 = std.rand.DefaultPrng.init(@as(u64,@intFromPtr(seed.ptr)));

        pub fn init(alloc: std.mem.Allocator) !Self {
            var types: [numTypes]T = undefined;
            var comps: [numComps]Component = undefined;

            inline for (typeTuple, 0..) |t,i| {
                types[i].comp_ids = std.ArrayList(usize).init(alloc);
                inline for(componentTuple,0..) |c,j| {
                    if(has_component(t, c)) {
                        types[i].comp_ids.append(j);
                    }
                }
            }

            inline for (componentTuple, 0..) |c,i| {
                comps[i].fields = alloc.alignedAlloc(*u8, type, 64, std.meta.fields(c).len);
                inline for(std.meta.fields(c),0..) |f,j| {
                    // INIT COMPS[] ARRAY
                    comps[i].fields[j] = alloc.alignedAlloc(f.type, f.alignment, 0);
                }
            }

            return .{
                .alloc = alloc,
                .types = types, 
                .comps = comps,
            };
        }

        fn has_component(comptime t: type, comptime c: type) bool {
            inline for(std.mem.fields(t)) |f| {
                if(f.type == c) {
                    return true;
                }
            }
            return false;
        }

        fn get_comp_id(comptime comp: type) usize {
            inline for(componentTuple,0..) |c,i| {
                if(comp == c) {
                    return i;
                }
            }
        }

        fn create_type_array(alloc: std.mem.Allocator, comptime typeArr: type, comptime compArr: type) [numTypes]T {
            var ret: [numTypes]T = undefined;
            var compCount: usize = 0;
            inline for(typeTuple, 0..) |t,i| {
                ret[i] = .{
                    .t = t,
                    .comp_ids = get_comp_id_array(alloc, t)
                };
                // compCount = compCount + t.
            }
        }

        fn get_comp_id_array(alloc: std.mem.Allocator, comptime t: type) []usize {
            var ret: []usize = alloc.alloc(usize, n: usize)
        }

        // pub fn append(self: *Self, t: anytype) !void {
        //     _ = t;
        //     _ = self;

        // }
        
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
    _ = alloc;
    const Goo = struct { pos: Pos = .{}, health: Health = .{} };
    const Foo = struct { pos: Pos = .{}, health: Health = .{}, attack: Attack = .{} };

    const Pos = struct { x: f32 = 0, y: f32 =0 };
    const Health = struct { health: f32 = 100, poison: f32 = 0 };
    const Attack = struct { strenth: f32 = 0, rebuff: f32 =0, whatever: f32 = 0 };

    const MAL = MultiTypeArray(.{Goo,Foo}, .{Pos,Health,Attack});
    _ = MAL;
    // var instance = try MAL.init(alloc);
    // _ = instance;
    // var foo: u32 = 0;
    // _ = foo;
}