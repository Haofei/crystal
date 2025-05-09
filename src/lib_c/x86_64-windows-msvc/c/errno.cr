lib LibC
  fun _get_errno(value : Int*) : ErrnoT
  fun _set_errno(value : Int) : ErrnoT

  # source https://docs.microsoft.com/en-us/cpp/c-runtime-library/errno-doserrno-sys-errlist-and-sys-nerr
  EPERM        =   1
  ENOENT       =   2
  ESRCH        =   3
  EINTR        =   4
  EIO          =   5
  ENXIO        =   6
  E2BIG        =   7
  ENOEXEC      =   8
  EBADF        =   9
  ECHILD       =  10
  EAGAIN       =  11
  ENOMEM       =  12
  EACCES       =  13
  EFAULT       =  14
  EBUSY        =  16
  EEXIST       =  17
  EXDEV        =  18
  ENODEV       =  19
  ENOTDIR      =  20
  EISDIR       =  21
  EINVAL       =  22
  ENFILE       =  23
  EMFILE       =  24
  ENOTTY       =  25
  EFBIG        =  27
  ENOSPC       =  28
  ESPIPE       =  29
  EROFS        =  30
  EMLINK       =  31
  EPIPE        =  32
  EDOM         =  33
  ERANGE       =  34
  EDEADLK      =  36
  ENAMETOOLONG =  38
  ENOLCK       =  39
  ENOSYS       =  40
  ENOTEMPTY    =  41
  EILSEQ       =  42
  STRUNCATE    =  80
  EADDRINUSE   = 100
  EALREADY     = 103
  ECONNABORTED = 106
  ECONNREFUSED = 107
  ECONNRESET   = 108
  EINPROGRESS  = 112
  EISCONN      = 113
  ELOOP        = 114
  ENOPROTOOPT  = 123

  alias ErrnoT = Int
end
