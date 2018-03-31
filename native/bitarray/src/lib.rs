#[macro_use] extern crate rustler;
//#[macro_use] extern crate rustler_codegen;
#[macro_use] extern crate lazy_static;

use std::sync::Mutex;

use rustler::{NifEnv, NifTerm, NifResult, NifEncoder};
use rustler::resource::ResourceArc;
use rustler::types::{NifBinary, OwnedNifBinary};
use rustler::schedule::NifScheduleFlags;


mod atoms {
    rustler_atoms! {
        atom ok;
        //atom error;
        //atom __true__ = "true";
        //atom __false__ = "false";
    }
}

struct BitArray {
    pub data : Mutex<Box<[u64]>>
}

rustler_export_nifs! {
    "Elixir.Flower.Native.BitArray",
    [("new", 1, new),
    ("from_bin", 1, from_bin, NifScheduleFlags::DirtyCpu),
    ("to_bin", 1, to_bin, NifScheduleFlags::DirtyCpu),
    ("put", 3, put),
    ("get", 2, get),
    ("bit_length", 1, bit_length),
    ("count_ones", 1, count_ones, NifScheduleFlags::DirtyCpu)],
    Some(on_load)
}

fn on_load<'a>(env: NifEnv<'a>, _info: NifTerm<'a>) -> bool {
    resource_struct_init!(BitArray, env);

    true
}

fn new<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let length: usize = try!(args[0].decode());

    let data: Box<[u64]> = vec![0; (length-1) / 64 + 1].into_boxed_slice();

    let resource : ResourceArc<BitArray> = ResourceArc::new(BitArray{
        data: Mutex::new(data)
    });

    Ok(resource.encode(env))
}

fn from_bin<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let bin: NifBinary = try!(args[0].decode());
    let bin64len = (bin.len()-1) / 8 + 1;

    let mut data: Box<[u64]> = vec![0; bin64len].into_boxed_slice();

    for x in 0..data.len() {
        data[x] = 0
            | ((bin[x*8 + 0] as u64) << 0*8)
            | ((bin[x*8 + 1] as u64) << 1*8)
            | ((bin[x*8 + 2] as u64) << 2*8)
            | ((bin[x*8 + 3] as u64) << 3*8)
            | ((bin[x*8 + 4] as u64) << 4*8)
            | ((bin[x*8 + 5] as u64) << 5*8)
            | ((bin[x*8 + 6] as u64) << 6*8)
            | ((bin[x*8 + 7] as u64) << 7*8);
    }

    let resource : ResourceArc<BitArray> = ResourceArc::new( BitArray{
        data: Mutex::new(data)
    });

    Ok(resource.encode(env))
}

fn to_bin<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let resource: ResourceArc<BitArray> = try!(args[0].decode());
    let data = resource.data.try_lock().unwrap();

    let mut erl_bin : OwnedNifBinary = OwnedNifBinary::new(data.len() * 8).unwrap();
    let bin = erl_bin.as_mut_slice();

    for x in 0usize..data.len() {
        for y in 0..8 {
            let i = x*8 + y;
            bin[i] = (data[x] >> (y*8)) as u8;
        }
    }

    Ok(erl_bin.release(env).encode(env))
}

fn put<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let resource: ResourceArc<BitArray> = try!(args[0].decode());
    let index: usize = try!(args[1].decode());
    let value: bool = try!(args[2].decode());

    let mut vec = resource.data.try_lock().unwrap();

    let mut word = vec[index / 64];

    if value {
        word = word | (1 << (index % 64));
    }else{
        word = word & !(1 << (index % 64));
    }

    vec[index / 64] = word;

    Ok(atoms::ok().encode(env))
}

fn get<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let resource: ResourceArc<BitArray> = try!(args[0].decode());
    let index: usize = try!(args[1].decode());

    let data = resource.data.try_lock().unwrap();

    let result = (data[index / 64] & (1 << (index % 64))) != 0;

    Ok(result.encode(env))
}

fn bit_length<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let resource: ResourceArc<BitArray> = try!(args[0].decode());
    let data = resource.data.try_lock().unwrap();

    Ok((data.len() * 64).encode(env))
}

fn count_ones<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let resource: ResourceArc<BitArray> = try!(args[0].decode());
    let data = resource.data.try_lock().unwrap();

    let mut count = 0usize;
    for x in data.iter() {
        count += x.count_ones() as usize;
    }

    Ok(count.encode(env))
}
