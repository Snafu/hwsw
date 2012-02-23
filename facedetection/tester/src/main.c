
#include <stdio.h>   
#include <string.h>  
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <fcntl.h> 
#include <errno.h> 
#include <termios.h> 
#include <signal.h>

#define CLKPERIOD 20
#define PRESCALER 4

int open_port(void)
{
  int fd;                                   /* File descriptor for the port */

  fd = open("/dev/ttyS0", O_RDWR | O_NOCTTY);
  if (fd == -1) {                                              /* Could not open the port */
    fprintf(stderr, "open_port: Unable to open /dev/ttyS0 - %s\n",
	    strerror(errno));
  }

  return (fd);
}

void UART_read(int fd, char *buf, int size) {
  int bytesToRead = size;
  int readBytes;
  while (bytesToRead > 0) {
    readBytes = read(fd, buf, bytesToRead);
    buf += readBytes;
    bytesToRead -= readBytes;
  }
}

void usage() {
  printf("Usage: ");
  printf("programmer <program.srec> <image_in.tga> <image_out.tga>\n");
  exit(0);
}

int main(int argc, char **argv)
{
  int serialfd=0;                                            /* File descriptor */
  struct termios options;
  FILE *f;
  uint32_t filesize = 0;
  unsigned char *imageData;
  unsigned char imageDataBlock[1024];
  int ret;
  uint32_t cycles;
  float seconds, fps;
  char buffer[64];

  if (argc != 4) {
    usage();
  }



  serialfd = open_port();

  //fcntl(serialfd, F_SETFL, FNDELAY);                  /* Configure port reading */
  // 115200, 8E1, no flow control
  bzero(&options, sizeof(options));
  cfsetispeed(&options, B115200);
  cfsetospeed(&options, B115200);

  /* Enable the receiver and set local mode */
  options.c_cflag |= (CLOCAL | CREAD);
  options.c_cflag |= PARENB; 
  options.c_cflag &= ~CSIZE;
  options.c_cflag |=  CS8;   
  options.c_cflag &= ~CRTSCTS;

  options.c_cc[VMIN]     = 1; 
  options.c_cc[VEOF]     = 0;
 
  /* Enable data to be processed as raw input */
  options.c_lflag &= ~(ICANON | ECHO | ISIG);

  options.c_iflag &= ~(IXOFF | IXON | IXANY);

  //options.c_lflag = ICANON;

  tcflush(serialfd, TCIFLUSH);       
  /* Set the new options for the port */


  tcsetattr(serialfd, TCSANOW, &options);

  // downloading program
  f = fopen(argv[1], "r");
  fseek(f, 0, SEEK_END);
  filesize = ftell(f);
  fseek(f, 0, SEEK_SET);
  imageData = (unsigned char *)malloc(filesize);
  filesize = fread(imageData, 1, filesize, f);
  fclose(f);
  printf("Downloading program, filesize: %d bytes.\n", filesize);
  filesize = write(serialfd, imageData, filesize);
  free(imageData);

  
  // downloading image
  f = fopen(argv[2], "r");
  if (!f) {
    printf("Image file <%s> not found", argv[2]);
    exit(1);
  }
  fseek(f, 0, SEEK_END);
  filesize = ftell(f);
  fseek(f, 0, SEEK_SET);
  imageData = (unsigned char *)malloc(filesize);
  fread(imageData, 1, filesize, f);
  fclose(f);

  // wait until program has been started on target
  sleep(2);

	// hglanzer - disabled
/*
  printf("Downloading image \"%s\", filesize: %d bytes.\n", argv[2], filesize);

 
 
  // send image file size
  write(serialfd, &filesize, sizeof(filesize));
  // send image data
  write(serialfd, imageData, filesize);
  free(imageData);
*/  
  options.c_lflag |= (ICANON);
  options.c_cc[VMIN]     = 0;
  tcsetattr(serialfd, TCSANOW, &options);

  printf("\n====== Debug messages of your program ======\n");
  // print debug messages
  while (1) {
    ret = read(serialfd, buffer, sizeof(buffer));            
    if (buffer[0] == 4) {
      // EOT
      break;
    }
    buffer[ret]=0;
    printf("%s", buffer);
  }
  printf("============================================\n\n");
  
  options.c_lflag &= ~ICANON;
  options.c_cc[VMIN]     = 1;
  tcsetattr(serialfd, TCSANOW, &options);
  
  UART_read(serialfd, (char *)&cycles, sizeof(cycles));
	printf("Cycles = %d\n", cycles);
  seconds = cycles;
  seconds /= 1000000000;
  seconds *= CLKPERIOD * PRESCALER;
  fps = 1 / seconds;

  printf("Computation completed, duration: %.3f sec, %.3f fps).\n", seconds, fps);

  UART_read(serialfd, (char *)&filesize, sizeof(filesize));

  f = fopen(argv[3], "w");
  if (!f) {
    printf("Image file <%s> couldn't be opened", argv[3]);
    exit(1);
  }
    
  while (filesize > 0) {
    int bytesToRead = ((filesize > 1024) ? 1024 : filesize);
    UART_read(serialfd, (char *)imageDataBlock, bytesToRead);
    fwrite(imageDataBlock, 1, bytesToRead, f);
    filesize -= bytesToRead;      
  }
  
  fclose(f);

  close(serialfd);

  return 0;
}

