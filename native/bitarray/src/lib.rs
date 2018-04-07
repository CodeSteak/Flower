#[macro_use] extern crate rustler;
//#[macro_use] extern crate rustler_codegen;
#[macro_use] extern crate lazy_static;

use std::cmp;
use std::sync::Mutex;

use rustler::{NifEnv, NifTerm, NifResult, NifEncoder};
use rustler::resource::ResourceArc;
use rustler::types::{NifBinary, OwnedNifBinary};


mod atoms {
    rustler_atoms! {
        atom ok;
        atom eof;
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
     ("to_bin_chunked", 2, to_bin_chunked),
     ("or_chunk", 3, or_chunk),
     ("put", 3, put),
     ("get", 2, get),
     ("bit_length", 1, bit_length),
     ("count_ones_chunked", 2, count_ones_chunked)
    ],
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

const CHUNK_SIZE_U64 : usize = 1024;

fn to_bin_chunked<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let resource: ResourceArc<BitArray> = try!(args[0].decode());
    let chunk_num: usize    = try!(args[1].decode());

    let data = resource.data.lock().unwrap();

    let offset    = chunk_num * CHUNK_SIZE_U64;
    let reminding = (data.len() as i64) - (offset as i64);

    let size      = cmp::min(CHUNK_SIZE_U64 as i64, reminding) as usize;

    let is_eof    = reminding <= (CHUNK_SIZE_U64 as i64);

    let erl_bin_byte_size = size * 8;

    let mut erl_bin : OwnedNifBinary = OwnedNifBinary::new(erl_bin_byte_size).unwrap();
    let bin = erl_bin.as_mut_slice();

    for x in 0..size {
        for y in 0..8 {
            let i = x*8 + y;
            bin[i] = (data[x + offset] >> (y*8)) as u8;
        }
    }

    if is_eof {
        Ok((atoms::eof(),erl_bin.release(env)).encode(env))
    }else {
        Ok((chunk_num + 1,erl_bin.release(env)).encode(env))
    }
}


fn or_chunk<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let resource: ResourceArc<BitArray> = try!(args[0].decode());
    let bin     : NifBinary             = try!(args[1].decode());
    let byte_offset  : usize            = try!(args[2].decode());


    let mut data = resource.data.lock().unwrap();


    for x in 0..bin.len() {
        let data_index   = (x + byte_offset) / 8;
        let bin_offset = (x + byte_offset) % 8;

        data[data_index] = data[data_index] | ((bin[x] as u64) << bin_offset*8);
    }

    Ok((byte_offset + bin.len()).encode(env))
}

fn put<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let resource: ResourceArc<BitArray> = try!(args[0].decode());
    let index: usize = try!(args[1].decode());
    let value: bool = try!(args[2].decode());

    let mut vec = resource.data.lock().unwrap();

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

    let data = resource.data.lock().unwrap();

    let result = (data[index / 64] & (1 << (index % 64))) != 0;

    Ok(result.encode(env))
}

fn bit_length<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let resource: ResourceArc<BitArray> = try!(args[0].decode());
    let data = resource.data.lock().unwrap();

    Ok((data.len() * 64).encode(env))
}

fn count_ones_chunked<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let resource: ResourceArc<BitArray> = try!(args[0].decode());
    let chunk_num: usize    = try!(args[1].decode());

    let data = resource.data.lock().unwrap();

    let offset    = chunk_num * CHUNK_SIZE_U64;
    let reminding = (data.len() as i64) - (offset as i64);
    let size      = cmp::min(CHUNK_SIZE_U64 as i64, reminding) as usize;
    let is_eof    = reminding <= (CHUNK_SIZE_U64 as i64);

    let mut count = 0usize;

    for x in 0..size {
        count += data[x + offset].count_ones() as usize;
    }

    if is_eof {
        Ok((atoms::eof(), count).encode(env))
    }else {
        Ok((chunk_num + 1, count).encode(env))
    }
}
