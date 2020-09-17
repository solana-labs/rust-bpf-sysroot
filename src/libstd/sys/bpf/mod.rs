//! System bindings for the BPF platform
//!
//! This module contains the facade (aka platform-specific) implementations of
//! OS level functionality for BPF
//!
//! This is all super highly experimental and not actually intended for
//! wide/production use yet, it's still all in the experimental category. This
//! will likely change over time.
//!
//! Currently all functions here are basically stubs that immediately return
//! errors. The hope is that with a portability lint we can turn actually just
//! remove all this and just omit parts of the standard library if we're
//! compiling for BPF. That way it's a compile time error for something that's
//! guaranteed to be a runtime error!

use crate::os::raw::c_char;
use crate::ptr;

pub mod alloc;
pub mod args;
#[cfg(feature = "backtrace")]
pub mod backtrace;
pub mod cmath;
pub mod env;
pub mod fs;
pub mod io;
pub mod memchr;
pub mod net;
pub mod os;
pub mod path;
pub mod pipe;
pub mod process;
pub mod thread;
pub mod time;
pub mod stdio;

pub mod condvar;
pub mod mutex;
pub mod rwlock;
pub mod thread_local;

pub use crate::sys_common::os_str_bytes as os_str;

pub fn sol_log(message: &str) {
    unsafe {
        sol_log_(message.as_ptr(), message.len() as u64);
    }
}
extern "C" {
    fn sol_log_(message: *const u8, length: u64);
}

#[allow(dead_code)]
pub fn sol_log_64(arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64) {
    unsafe {
        sol_log_64_(arg1, arg2, arg3, arg4, arg5);
    }
}
extern "C" {
    fn sol_log_64_(arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64);
}

pub fn panic(info: &core::panic::PanicInfo<'_>) -> ! {
    sol_log("libstd bpf panic");
    unsafe { sol_panic_(ptr::null(), 0, 0, 0) }
    // // Message is ignored for now to avoid incurring formatting overhead
    // match info.location() {
    //     Some(location) => {
    //         let mut file: [u8; 128] = [0; 128];
    //         for (i, c) in location.file().as_bytes().iter().enumerate() {
    //             if i > 127 {
    //                 break;
    //             }
    //             file[i] = *c;
    //         }
    //         unsafe {
    //             sol_panic_(
    //                 file.as_ptr(),
    //                 file.len() as u64,
    //                 u64::from(location.line()),
    //                 u64::from(location.column()),
    //             );
    //         }
    //     }
    //     None => unsafe { 
    //         sol_panic_(ptr::null(), 0, 0, 0)
    //     },
    // }
}
extern "C" {
    fn sol_panic_(file: *const u8, len: u64, line: u64, column: u64) -> !;
}

// #[cfg(not(test))]
// pub fn init() {
// }

pub fn unsupported<T>() -> crate::io::Result<T> {
    Err(unsupported_err())
}

pub fn unsupported_err() -> crate::io::Error {
    crate::io::Error::new(crate::io::ErrorKind::Other,
                   "operation not supported on BPF yet")
}

pub fn decode_error_kind(_code: i32) -> crate::io::ErrorKind {
    crate::io::ErrorKind::Other
}

// This enum is used as the storage for a bunch of types which can't actually
// exist.
#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, Debug, Hash)]
pub enum Void {}

pub unsafe fn strlen(mut s: *const c_char) -> usize {
    let mut n = 0;
    while *s != 0 {
        n += 1;
        s = s.offset(1);
    }
    return n
}

pub unsafe fn abort_internal() -> ! {
    sol_panic_(core::ptr::null(), 0, 0, 0);
}

// We don't have randomness yet, but I totally used a random number generator to
// generate these numbers.
//
// More seriously though this is just for DOS protection in hash maps. It's ok
// if we don't do that on BPF just yet.
pub fn hashmap_random_keys() -> (u64, u64) {
    (1, 2)
}
