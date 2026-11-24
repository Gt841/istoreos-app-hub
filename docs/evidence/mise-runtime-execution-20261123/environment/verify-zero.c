/* Read-only blank-device verifier. Does not open any device for writing. */
#define _FILE_OFFSET_BITS 64
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <linux/fs.h>
#include <errno.h>
int main(int argc,char **argv) {
  if(argc!=3) return 2;
  char *end; uint64_t expected=strtoull(argv[2],&end,10),size=0,total=0;
  if(*end||expected==0) return 2;
  int fd=open(argv[1],O_RDONLY|O_CLOEXEC); struct stat st;
  if(fd<0||fstat(fd,&st)||!S_ISBLK(st.st_mode)||ioctl(fd,BLKGETSIZE64,&size)||size!=expected) return 3;
  uint64_t *buf=malloc(4*1024*1024); if(!buf)return 4;
  for(;;) {
    ssize_t n=read(fd,buf,4*1024*1024);
    if(n<0){if(errno==EINTR)continue;return 5;} if(n==0)break;
    uint64_t acc=0;size_t i=0;
    for(;i<(size_t)n/8;i++)acc|=buf[i];
    const unsigned char *tail=(const unsigned char*)buf;
    for(i=(size_t)n/8*8;i<(size_t)n;i++)acc|=tail[i];
    if(acc){fprintf(stderr,"nonzero-byte-in-chunk offset=%llu\n",(unsigned long long)total);return 6;}
    total+=(uint64_t)n;
  }
  close(fd);free(buf);
  if(total!=expected)return 7;
  printf("all-zero bytes=%llu device=%s\n",(unsigned long long)total,argv[1]);return 0;
}
