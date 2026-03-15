/*
 * getopt.c - cross-platform getopt implementation
 * For use on platforms that don't provide getopt (e.g. Windows/MSVC)
 *
 * Based on the public domain implementation by Todd C. Miller.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "getopt.h"

/* If the platform already provides getopt (Linux, macOS), skip this file */
#if defined(_WIN32) || defined(__MINGW32__) || defined(__MINGW64__)

char *optarg = NULL;
int   optind = 1;
int   opterr = 1;
int   optopt = '?';

int getopt(int argc, char * const argv[], const char *optstring)
{
    static char *place = (char *)"";
    const char *oli;
    char *p;

    if (!*place) {
        if (optind >= argc || *(place = argv[optind]) != '-') {
            place = (char *)"";
            return -1;
        }
        if (place[1] && *++place == '-') {
            ++optind;
            place = (char *)"";
            return -1;
        }
    }

    optopt = (int)*place++;
    oli = strchr(optstring, optopt);

    if (!oli) {
        if (!*place) ++optind;
        if (opterr && *optstring != ':')
            fprintf(stderr, "illegal option -- %c\n", optopt);
        return '?';
    }

    if (oli[1] != ':') {
        if (!*place) ++optind;
        optarg = NULL;
    } else {
        if (*place) {
            optarg = place;
        } else if (argc <= ++optind) {
            place = (char *)"";
            if (*optstring == ':') return ':';
            if (opterr) fprintf(stderr, "option requires an argument -- %c\n", optopt);
            return '?';
        } else {
            optarg = argv[optind];
        }
        place = (char *)"";
        ++optind;
    }

    return optopt;
}

#else
/* On POSIX systems getopt is already provided by <unistd.h> / libc.
   We still need to expose the symbols so the header doesn't break. */
#include <unistd.h>
#endif
