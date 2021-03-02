use crate::cell::Cell;

pub struct RWLock {
    // This platform has no threads, so we can use a Cell here.
    mode: Cell<isize>,
}

unsafe impl Send for RWLock {}
unsafe impl Sync for RWLock {} // no threads on this platform

impl RWLock {
    pub const fn new() -> RWLock {
        RWLock { mode: Cell::new(0) }
    }

    #[inline]
    pub unsafe fn read(&self) {
        let m = self.mode.get();
        if m >= 0 {
            self.mode.set(m + 1);
        } else {
            rtabort!("rwlock locked for writing");
        }
    }

    #[inline]
    pub unsafe fn try_read(&self) -> bool {
        let m = self.mode.get();
        if m >= 0 {
            self.mode.set(m + 1);
            true
        } else {
            false
        }
    }

    #[inline]
    pub unsafe fn write(&self) {
        if self.mode.replace(-1) != 0 {
            rtabort!("rwlock locked for reading")
        }
    }

    #[inline]
    pub unsafe fn try_write(&self) -> bool {
        if self.mode.get() == 0 {
            self.mode.set(-1);
            true
        } else {
            false
        }
    }

    #[inline]
    pub unsafe fn read_unlock(&self) {
        self.mode.set(self.mode.get() - 1);
    }

    #[inline]
    pub unsafe fn write_unlock(&self) {
        assert_eq!(self.mode.replace(0), -1);
    }

    #[inline]
    pub unsafe fn destroy(&self) {}
}
