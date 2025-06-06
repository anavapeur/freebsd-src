#!/bin/sh

# Fatal trap 12: page fault while in kernel mode
# cpuid = 10; apic id = 07
# fault virtual address   = 0x0
# fault code              = supervisor read data, page not present
# instruction pointer     = 0x20:0xffffffff80c3c276
# stack pointer           = 0x28:0xfffffe017273eb00
# frame pointer           = 0x28:0xfffffe017273eb30
# code segment            = base 0x0, limit 0xfffff, type 0x1b
#                         = DPL 0, pres 1, long 1, def32 0, gran 1
# processor eflags        = interrupt enabled, resume, IOPL = 0
# current process         = 43905 (syzkaller78)
# rdi: fffff8005b5d55e0 rsi: 0000000000000008 rdx: ffffffff81249e88
# rcx: fffff8001b9aed00  r8: 0000000000000000  r9: fffff80003396000
# rax: 0000000000000000 rbx: fffff8005b5d5400 rbp: fffffe017273eb30
# r10: 0000000000000000 r11: fffff804d84e9c60 r12: fffff8005b5d55f8
# r13: 0000000000000000 r14: fffff80497171700 r15: fffff8005b5d55c0
# trap number             = 12
# panic: page fault
# cpuid = 7
# time = 1746555157
# KDB: stack backtrace:
# db_trace_self_wrapper() at db_trace_self_wrapper+0x2b/frame 0xfffffe017273e830
# vpanic() at vpanic+0x136/frame 0xfffffe017273e960
# panic() at panic+0x43/frame 0xfffffe017273e9c0
# trap_pfault() at trap_pfault+0x48d/frame 0xfffffe017273ea30
# calltrap() at calltrap+0x8/frame 0xfffffe017273ea30
# --- trap 0xc, rip = 0xffffffff80c3c276, rsp = 0xfffffe017273eb00, rbp = 0xfffffe017273eb30 ---
# unp_dispose() at unp_dispose+0x3b6/frame 0xfffffe017273eb30
# uipc_detach() at uipc_detach+0x35/frame 0xfffffe017273eb80
# sorele_locked() at sorele_locked+0x107/frame 0xfffffe017273ebb0
# soclose() at soclose+0x17d/frame 0xfffffe017273ec10
# _fdrop() at _fdrop+0x1b/frame 0xfffffe017273ec30
# closef() at closef+0x1e3/frame 0xfffffe017273ecc0
# fdescfree() at fdescfree+0x41e/frame 0xfffffe017273ed80
# exit1() at exit1+0x4a4/frame 0xfffffe017273edf0
# sys_exit() at sys_exit+0xd/frameamd64_syscall() at amd64_syscall+0x15a/frame 0xfffffe017273ef30
# fast_syscall_common() at fast_syscall_common+0xf8/frame 0xfffffe017273ef30 
# --- syscall (1, FreeBSD ELF64, exit), rip = 0x823ab472a, rsp = 0x8208e3ea8, rbp = 0x8208e3ec0 ---
# KDB: enter: panic
# [ thread pid 43905 tid 103344 ]
# Stopped at      kdb_enter+0x33: movq    $0,0x122f202(%rip)
# db> 

[ `id -u ` -ne 0 ] && echo "Must be root!" && exit 1

. ../default.cfg
set -u
prog=$(basename "$0" .sh)
cat > /tmp/$prog.c <<EOF
// https://syzkaller.appspot.com/bug?id=46eb92ee6e2f6acbd4250d0f2065b1f93296bd82
// autogenerated by syzkaller (https://github.com/google/syzkaller)
// syzbot+0e99ffc200638909ca1c@syzkaller.appspotmail.com

#define _GNU_SOURCE

#include <sys/types.h>

#include <dirent.h>
#include <errno.h>
#include <pwd.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/endian.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static unsigned long long procid;

static void kill_and_wait(int pid, int* status)
{
  kill(pid, SIGKILL);
  while (waitpid(-1, status, 0) != pid) {
  }
}

static void sleep_ms(uint64_t ms)
{
  usleep(ms * 1000);
}

static uint64_t current_time_ms(void)
{
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts))
    exit(1);
  return (uint64_t)ts.tv_sec * 1000 + (uint64_t)ts.tv_nsec / 1000000;
}

static void use_temporary_dir(void)
{
  char tmpdir_template[] = "./syzkaller.XXXXXX";
  char* tmpdir = mkdtemp(tmpdir_template);
  if (!tmpdir)
    exit(1);
  if (chmod(tmpdir, 0777))
    exit(1);
  if (chdir(tmpdir))
    exit(1);
}

static void reset_flags(const char* filename)
{
  struct stat st;
  if (lstat(filename, &st))
    exit(1);
  st.st_flags &= ~(SF_NOUNLINK | UF_NOUNLINK | SF_IMMUTABLE | UF_IMMUTABLE |
                   SF_APPEND | UF_APPEND);
  if (lchflags(filename, st.st_flags))
    exit(1);
}
static void __attribute__((noinline)) remove_dir(const char* dir)
{
  DIR* dp = opendir(dir);
  if (dp == NULL) {
    if (errno == EACCES) {
      if (rmdir(dir))
        exit(1);
      return;
    }
    exit(1);
  }
  struct dirent* ep = 0;
  while ((ep = readdir(dp))) {
    if (strcmp(ep->d_name, ".") == 0 || strcmp(ep->d_name, "..") == 0)
      continue;
    char filename[FILENAME_MAX];
    snprintf(filename, sizeof(filename), "%s/%s", dir, ep->d_name);
    struct stat st;
    if (lstat(filename, &st))
      exit(1);
    if (S_ISDIR(st.st_mode)) {
      remove_dir(filename);
      continue;
    }
    if (unlink(filename)) {
      if (errno == EPERM) {
        reset_flags(filename);
        reset_flags(dir);
        if (unlink(filename) == 0)
          continue;
      }
      exit(1);
    }
  }
  closedir(dp);
  while (rmdir(dir)) {
    if (errno == EPERM) {
      reset_flags(dir);
      if (rmdir(dir) == 0)
        break;
    }
    exit(1);
  }
}

static void execute_one(void);

#define WAIT_FLAGS 0

static void loop(void)
{
  int iter = 0;
  for (;; iter++) {
    char cwdbuf[32];
    sprintf(cwdbuf, "./%d", iter);
    if (mkdir(cwdbuf, 0777))
      exit(1);
    int pid = fork();
    if (pid < 0)
      exit(1);
    if (pid == 0) {
      if (chdir(cwdbuf))
        exit(1);
      execute_one();
      exit(0);
    }
    int status = 0;
    uint64_t start = current_time_ms();
    for (;;) {
      sleep_ms(10);
      if (waitpid(-1, &status, WNOHANG | WAIT_FLAGS) == pid)
        break;
      if (current_time_ms() - start < 5000)
        continue;
      kill_and_wait(pid, &status);
      break;
    }
    remove_dir(cwdbuf);
  }
}

uint64_t r[5] = {0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff,
                 0xffffffffffffffff, 0xffffffffffffffff};

void execute_one(void)
{
  intptr_t res = 0;
  if (write(1, "executing program\n", sizeof("executing program\n") - 1)) {
  }
  memcpy((void*)0x200000000480, "./file0\000", 8);
  res = syscall(
      SYS_open, /*file=*/0x200000000480ul,
      /*flags=O_NONBLOCK|O_CREAT|O_RDWR|0x80000000000000*/ 0x80000000000206ul,
      /*mode=*/0ul);
  if (res != -1)
    r[0] = res;
  syscall(SYS_ftruncate, /*fd=*/r[0], /*len=*/0x3862ul);
  memcpy((void*)0x200000000100, "./file0\000", 8);
  res = syscall(SYS_open, /*file=*/0x200000000100ul,
                /*flags=O_DIRECT*/ 0x10000ul, /*mode=*/0ul);
  if (res != -1)
    r[1] = res;
  *(uint64_t*)0x2000000000c0 = 0x200000000340;
  *(uint64_t*)0x2000000000c8 = 0x41;
  syscall(SYS_readv, /*fd=*/r[1], /*vec=*/0x2000000000c0ul, /*vlen=*/1ul);
  res = syscall(SYS_socket, /*domain=*/2ul, /*type=*/2ul, /*proto=*/0x88);
  if (res != -1)
    r[2] = res;
  res = syscall(SYS_socketpair, /*domain=*/1ul, /*type=SOCK_STREAM*/ 1ul,
                /*proto=*/0, /*fds=*/0x200000000180ul);
  if (res != -1)
    r[3] = *(uint32_t*)0x200000000180;
  syscall(SYS_dup2, /*oldfd=*/r[3], /*newfd=*/r[2]);
  memcpy((void*)0x200000000140, "./file0\000", 8);
  res =
      syscall(SYS_open, /*file=*/0x200000000140ul, /*flags=*/0ul, /*mode=*/0ul);
  if (res != -1)
    r[4] = res;
  syscall(SYS_sendfile, /*fd=*/r[4], /*s=*/r[2], /*offset=*/0xcbul,
          /*nbytes=*/0x2000ul, /*hdtr=*/0ul, /*sbytes=*/0ul,
          /*flags=SF_USER_READAHEAD|SF_NODISKIO|0x2*/ 0xbul);
}
int main(void)
{
  syscall(SYS_mmap, /*addr=*/0x200000000000ul, /*len=*/0x1000000ul,
          /*prot=PROT_WRITE|PROT_READ|PROT_EXEC*/ 7ul,
          /*flags=MAP_FIXED|MAP_ANONYMOUS|MAP_PRIVATE*/ 0x1012ul,
          /*fd=*/(intptr_t)-1, /*offset=*/0ul);
  const char* reason;
  (void)reason;
  for (procid = 0; procid < 4; procid++) {
    if (fork() == 0) {
      use_temporary_dir();
      loop();
    }
  }
  sleep(1000000);
  return 0;
}
EOF
mycc -o /tmp/$prog -Wall -Wextra -O0 /tmp/$prog.c -lpthread || exit 1

(cd ../testcases/swap; ./swap -t 3m -i 30 -l 100 > /dev/null 2>&1) &
sleep 5

work=/tmp/$prog.dir
rm -rf $work
mkdir $work
cd /tmp/$prog.dir
for i in `jot 30`; do
	(
		mkdir d$i
		cd d$i
		timeout 3m /tmp/$prog > /dev/null 2>&1 &
	)
done
while pgrep -q $prog; do sleep 2; done
while pkill swap; do :; done
wait

rm -rf /tmp/$prog /tmp/$prog.c /tmp/$prog.core /tmp/$prog.?????? $work
exit 0
