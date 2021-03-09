use super::make_command_line;
use crate::ffi::{OsStr, OsString};

#[test]
fn test_make_command_line() {
    fn test_wrapper(prog: &str, args: &[&str]) -> String {
        let command_line = &make_command_line(
            OsStr::new(prog),
            &args.iter().map(|a| OsString::from(a)).collect::<Vec<OsString>>(),
        )
        .unwrap();
        String::from_utf16(command_line).unwrap()
    }

    assert_eq!(test_wrapper("prog", &["aaa", "bbb", "ccc"]), "\"prog\" aaa bbb ccc");

    assert_eq!(
        test_wrapper("C:\\Program Files\\blah\\blah.exe", &["aaa"]),
        "\"C:\\Program Files\\blah\\blah.exe\" aaa"
    );
    assert_eq!(
        test_wrapper("C:\\Program Files\\test", &["aa\"bb"]),
        "\"C:\\Program Files\\test\" aa\\\"bb"
    );
    assert_eq!(test_wrapper("echo", &["a b c"]), "\"echo\" \"a b c\"");
    assert_eq!(test_wrapper("echo", &["\" \\\" \\", "\\"]), "\"echo\" \"\\\" \\\\\\\" \\\\\" \\");
    assert_eq!(
        test_wrapper("\u{03c0}\u{042f}\u{97f3}\u{00e6}\u{221e}", &[]),
        "\"\u{03c0}\u{042f}\u{97f3}\u{00e6}\u{221e}\""
    );
}
