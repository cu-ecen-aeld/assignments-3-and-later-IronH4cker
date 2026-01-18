
#include <sys/types.h>
#include <sys/wait.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdarg.h>
#include <stdio.h>

#include <unistd.h>
#include <fcntl.h>
#include <errno.h>



/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed
 *   successfully using the system() call, false if an error occurred,
 *   either in invocation of the system() call, or if a non-zero return
 *   value was returned by the command issued in @param cmd.
*/
bool do_system(const char *cmd)
{
/*
 * TODO  add your code here
 *  Call the system() function with the command set in the cmd
 *   and return a boolean true if the system() call completed with success
 *   or false() if it returned a failure
*/
    int status = 0;	
    int code = 0;
    if(cmd == NULL){
	return false;
    }else{
	//If cmd is a valid VALUE we call to system(cmd)
	//It is a call to a Standard Library C which allows 
	//execute a command of OS using shell, usin /bin/sh -c
	//This function is declarated in stdlib.h
	//According to intuition make something like this:
	//1.- fork() : Create a child process
	//2.- execve("/bin/sh", ["sh, "-c", command], env): (cons char *pathname, char *const argv[], char *const envp[])
	//It is a Linux syscall which replace the current process by a shell (/bin/sh) and order execute the text command as a shell command
	//after a succesful execve() hte original code disappear, the PID does not change, memory, stack and code are replaced, and it does not come back to the next line
	//3.- waitpid(): The father wait until child finish
	//Examples--> system("ls -l");
	//	      system("echo hola");
	//	      system("mkdir -p /tmp/test");
	status = system(cmd);
	if(status == -1){
	  return false;	
	}
	//WIFEXITED: Macro which check if the child process finish as a normal way and it did not die by a SIGNAL, what that means it called exit(code) + return code form main
	if(WIFEXITED(status) != 0){ //output: !=0(TRUE): Process finished well ;; 0(FALSE): The process died due to a signal (SIGSEGV=segmentation fault, SIGKILL=kill child, SIGABRT=abort ,etc) 
				    //or was stopped or suspended 
		//WEXITSTATUS: Macro which extract or parse the real exit code of the child process, this macro must be used only if the WIFEXITED has been successed
		code = WEXITSTATUS(status);
		if(code == 0){ //output: integer among 0 -255 --> 0: Success (Unix convention);; !=0: Error
			return true;
		}
		else
		{
			printf("Error code : %d\n", code);
			if((code & 0xF0) != 0)
			{
				printf("Exit code: %d\n", (code>>8));
			}
			else if((code & 0x0F) != 0)
			{
				printf("Signal code: %d\n", code);
			}
			return false;
		}
	}
    }
    return false;    
}

/**
* @param count -The numbers of variables passed to the function. The variables are command to execute.
*   followed by arguments to pass to the command
*   Since exec() does not perform path expansion, the command to execute needs
*   to be an absolute path.
* @param ... - A list of 1 or more arguments after the @param count argument.
*   The first is always the full path to the command to execute with execv()
*   The remaining arguments are a list of arguments to pass to the command in execv()
* @return true if the command @param ... with arguments @param arguments were executed successfully
*   using the execv() call, false if an error occurred, either in invocation of the
*   fork, waitpid, or execv() command, or if a non-zero return value was returned
*   by the command issued in @param arguments with the specified arguments.
*/

bool do_exec(int count, ...)
{

    if(count < 0 )
    {
	return false;	   
    }

    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    int code;
    int output = false;

    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
    // this line is to avoid a compile warning before your implementation is complete
    // and may be removed
    command[count] = command[count];

/*
 * TODO:
 *   Execute a system command by calling fork, execv(),
 *   and wait instead of system (see LSP page 161).
 *   Use the command[0] as the full path to the command to execute
 *   (first argument to execv), and use the remaining arguments
 *   as second argument to the execv() command.
 *
*/
    va_end(args);

    fflush(stdout); //avoid duplicated prints after a fork

    pid_t pid_kid = fork(); //Create a kid process from a father process

    if(pid_kid < 0){
	return false;
    }

    if(pid_kid == 0)
    {
	execv(command[0], command); // Replace the kid  process by the command
	//If we are here, execv fail
	_exit(1);	
    }

    int status = 0;
    // The father process wait until the kid process is finished 
    if(waitpid(pid_kid, &status, 0) < 0 ) {
	return false;
    }

    code = WIFEXITED(status);

    if(code != 0)
    {
	if(WEXITSTATUS(status) == 0)
	{
	  output = true;
	}
	else
	{
	  output = false;
	}
    }

    return output;
}

/**
* @param outputfile - The full path to the file to write with command output.
*   This file will be closed at completion of the function call.
* All other parameters, see do_exec above
*/
bool do_exec_redirect(const char *outputfile, int count, ...)
{

    if((outputfile == NULL) || (count < 1))
    {
	return false;
    }	    

    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }

/*
 * TODO
 *   Call execv, but first using https://stackoverflow.com/a/13784315/1446624 as a refernce,
 *   redirect standard out to a file specified by outputfile.
 *   The rest of the behaviour is same as do_exec()
 *
*/

    va_end(args);
 
    command[count] = NULL;

    // this line is to avoid a compile warning before your implementation is complete
    // and may be removed
    command[count] = command[count];

   
    fflush(stdout);

   pid_t pid_child = fork();

   if(pid_child < 0)
   {
	return false;
   }

   if(pid_child == 0)
   {
	int fd = open(outputfile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	
	if(fd < 0)
	{
	  _exit(1);
	}

	if(dup2(fd, STDOUT_FILENO) < 0){
		close(fd);
		_exit(1);
	}

	close(fd);

	execv(command[0], command);
	_exit(1);

   }


   int status = 0;
   if(waitpid(pid_child, &status, 0) < 0){
   	return false;
   }


    return ((WIFEXITED(status)) && (WEXITSTATUS(status) == 0));
}
