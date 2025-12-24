#include <stdio.h> //FILE, fopen(), fputs(), fclose(), fprintf(), stderr
#include <syslog.h> //openlog(), syslog(), closelog(), LOG_PID, LOG_USER, LOG_ERR, LOG_DEBUG
#include <string.h> // strerror(errno): convert a number of error (errno) to a message
#include <errno.h> //Provide global variable errno which is a integer, set functions fo system automatically when a fail happen, and indicate what kind of error has happened


int main(int argc, char *argv[])
{
	//argv[0]: "./writer"
	//argv[1]: "writefile"
	//argv[2]: "writestr"
	char *writefile = argv[1];
	char *writestr = argv[2];


	//Open syslog: Identifier "writer", including PID, facility LOG_USER
	openlog("writer", LOG_PID, LOG_USER);


	if(argc < 2)
	{
		syslog(LOG_ERR, "Wrong number of arguments: %d", argc - 1);
		fprintf(stderr, "Usage: %s <writefile> <writestr>\n", argv[0]);
		closelog();
		return 1;
	}

	//syslog( Type Log,
	//	  Message Log,
	//	  Variables to print
	syslog(LOG_DEBUG, "Writing %s to %s", writestr, writefile );

	//Create a file Descriptor from writefile
	FILE *fp = fopen(writefile, "w");
	if(fp == NULL) 
	{
		syslog(LOG_ERR, "Error opening file %s: %s", writefile, strerror(errno));
		closelog();
		return 1;
	}

	//fputs write contain in file descriptor
	if(fputs(writestr, fp) == EOF)
	{
		syslog(LOG_ERR, "Error writing to file %s: %s", writefile, strerror(errno));
		fclose(fp);
		closelog();
		return 1;

	}

	if(fclose(fp) != 0)
	{
		syslog(LOG_ERR, "It is not possible close file %s: %s", writefile, strerror(errno));
		closelog();
		return 1;
	}
	
	closelog();
	return 0;
}
