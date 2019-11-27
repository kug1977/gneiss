
#include <stdio.h>
#include <sys/epoll.h>

void gneiss_epoll_create(int *efd)
{
    *efd = epoll_create1(0);
    if(*efd < 0){
        perror("epoll_create1");
    }
}

#define gneiss_epoll_add(name, type) \
    void gneiss_epoll_add_##name(int efd, int fd, type priv, int *success) \
{ \
    struct epoll_event eev; \
    eev.events = EPOLLRDHUP; \
    eev.data.name = priv; \
    *success = epoll_ctl(efd, EPOLL_CTL_ADD, fd, &eev); \
    if(*success < 0){ \
        perror("epoll_ctl"); \
    } \
}

gneiss_epoll_add(fd, int)
gneiss_epoll_add(ptr, void *)

void gneiss_epoll_remove(int efd, int fd, int *success)
{
    *success = epoll_ctl(efd, EPOLL_CTL_DEL, fd, 0);
    if(*success < 0){
        perror("epoll_ctl");
    }
}

#define gneiss_epoll_wait(name, type) \
    void gneiss_epoll_wait_##name(int efd, uint32_t *event, type *priv) \
{ \
    struct epoll_event eev; \
    eev.events = 0; \
    eev.data.name = 0; \
    if(epoll_wait(efd, &eev, 1, -1) < 0){ \
        perror("epoll_wait"); \
    } \
    *priv = eev.data.name; \
    *event = eev.events; \
}

gneiss_epoll_wait(fd, int)
gneiss_epoll_wait(ptr, void *)