/*
 * getopt.h - cross-platform getopt implementation
 * For use on platforms that don't provide getopt (e.g. Windows/MSVC)
 */

#ifndef __GETOPT_H__
#define __GETOPT_H__

#ifdef __cplusplus
extern "C" {
#endif

extern char *optarg;
extern int   optind;
extern int   opterr;
extern int   optopt;

int getopt(int argc, char * const argv[], const char *optstring);

#ifdef __cplusplus
}
#endif

#endif /* __GETOPT_H__ */
