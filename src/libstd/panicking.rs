//! Implementation of various bits and pieces of the `panic!` macro and
//! associated runtime pieces.
//!
//! Specifically, this module contains the implementation of:
//!
//! * Panic hooks
//! * Executing a panic up to doing the actual implementation
//! * Shims around "try"

// Note: The panicking functions have been stripped and rewritten 
//       in order to same space in BPF programs.  Panic messages
//       are not supported, just file, line, column

use core::panic::{PanicInfo, Location};

use crate::fmt;

/// Determines whether the current thread is unwinding because of panic.
pub fn panicking() -> bool {
    true
}

/// Entry point of panic from the libcore crate.
#[cfg(not(test))]
#[panic_handler]
#[unwind(allowed)]
pub fn rust_begin_panic(info: &PanicInfo<'_>) -> ! {
    crate::sys::panic(info);
}

/// The entry point for panicking with a formatted message.
///
/// This is designed to reduce the amount of code required at the call
/// site as much as possible (so that `panic!()` has as low an impact
/// on (e.g.) the inlining of other functions as possible), by moving
/// the actual formatting into this shared place.
#[unstable(feature = "libstd_sys_internals",
           reason = "used by the panic! macro",
           issue = "0")]
#[cold]
// If panic_immediate_abort, inline the abort call,
// otherwise avoid inlining because of it is cold path.
#[cfg_attr(not(feature="panic_immediate_abort"),inline(never))]
#[cfg_attr(    feature="panic_immediate_abort" ,inline)]
pub fn begin_panic_fmt(_msg: &fmt::Arguments<'_>,
                       file_line_col: &(&'static str, u32, u32)) -> ! {
    begin_panic(file_line_col);
}

/// Entry point of panicking for panic!() and assert!().
#[unstable(feature = "libstd_sys_internals",
           reason = "used by the panic! macro",
           issue = "0")]
#[cfg_attr(not(test), lang = "begin_panic")]
// never inline unless panic_immediate_abort to avoid code
// bloat at the call sites as much as possible
#[cfg_attr(not(feature="panic_immediate_abort"),inline(never))]
#[cold]
pub fn begin_panic(file_line_col: &(&'static str, u32, u32)) -> ! {
    let (file, line, col) = *file_line_col;
    let info = PanicInfo::internal_constructor(
        None,
        Location::internal_constructor(file, line, col),
    );
    crate::sys::panic(&info);
}
