fn main() {
    // Emit the rb-sys link flags for the host Ruby so the cdylib links libruby.
    let _ = rb_sys_env::activate().expect("rb-sys-env: failed to locate the host Ruby");
}
