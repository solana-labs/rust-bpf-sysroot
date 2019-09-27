#[allow(dead_code)]
#[cfg(not(target_arch = "bpf"))]
pub unsafe fn start_thread(main: *mut u8) {
    // Next, set up our stack overflow handler which may get triggered if we run
    // out of stack.
    let _handler = crate::sys::stack_overflow::Handler::new();

    // Finally, let's run some code.
    Box::from_raw(main as *mut Box<dyn FnOnce()>)()
}

#[cfg(not(target_arch = "bpf"))]
pub fn min_stack() -> usize {
    use crate::sync::atomic::{self, Ordering};
    static MIN: atomic::AtomicUsize = atomic::AtomicUsize::new(0);
    match MIN.load(Ordering::SeqCst) {
        0 => {}
        n => return n - 1,
    }
    let amt = crate::env::var("RUST_MIN_STACK").ok().and_then(|s| s.parse().ok());
    let amt = amt.unwrap_or(crate::sys::thread::imp::DEFAULT_MIN_STACK_SIZE);

    // 0 is our sentinel value, so ensure that we'll never see 0 after
    // initialization has run
    MIN.store(amt + 1, Ordering::SeqCst);
    amt
}
#[cfg(target_arch = "bpf")]
pub fn min_stack() -> usize {
    0
}
