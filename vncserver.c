#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <libvncserver/libvncserver.h>

struct settings {
    int port;
    int width;
    int height;
    char *password;
};

static char *framebuffer;

static void
usage(void)
{
    fprintf(stderr, "usage: vncserver [-p port] [-w width] [-h height] [-P password]\n");
}

static void
readFrameBuffer(void)
{
    CGDirectAccessRec dax;
    CGDisplayRef display = CGMainDisplayID();

    if (CGDisplayBeginDirectAccess(display, "vncserver", &dax) != kCGErrorSuccess) {
        return;
    }
    memcpy(framebuffer, dax.base, dax.bytesPerRow * dax.height);
    CGDisplayEndDirectAccess(display, "vncserver", &dax);
}

int
main(int argc, char *argv[])
{
    struct settings settings = {
        .port = 5900,
        .width = 0,
        .height = 0,
        .password = NULL,
    };
    int opt;

    while ((opt = getopt(argc, argv, "p:w:h:P:")) != -1) {
        switch (opt) {
        case 'p':
            settings.port = atoi(optarg);
            break;
        case 'w':
            settings.width = atoi(optarg);
            break;
        case 'h':
            settings.height = atoi(optarg);
            break;
        case 'P':
            settings.password = strdup(optarg);
            break;
        default:
            usage();
            return 1;
        }
    }

    CGDisplayRef display = CGMainDisplayID();
    int pixelDepth = 24;
    int bytesPerPixel = 4;

    int deviceWidth = CGDisplayPixelsWide(display);
    int deviceHeight = CGDisplayPixelsHigh(display);

    /* Prefer the custom resolution from the settings; otherwise use the
     * device's native screen size. */
    int width = settings.width > 0 ? settings.width : deviceWidth;
    int height = settings.height > 0 ? settings.height : deviceHeight;

    framebuffer = (char *)malloc(width * height * bytesPerPixel);

    struct vncServerDef vnc = {
        .auth = VNC_AUTH_NONE,
        .authPassword = settings.password,
        .maxClients = 1,
    };

    vncServerListener *server = vncserver_init(&vnc, settings.port, width, height,
                                               pixelDepth, bytesPerPixel);
    if (!server) {
        fprintf(stderr, "Failed to initialize VNC server\n");
        free(framebuffer);
        return 1;
    }

    vncserver_setSharedDesktop(&vnc, TRUE);
    vncserver_setAlwaysShared(&vnc, TRUE);

    vncClientPtr client;
    int running = 1;
    while (running) {
        readFrameBuffer();
        client = vncserver_client_wait(server, &running, 1000);
        while (client) {
            vncserver_wait_pixel_format(client);
            readFrameBuffer();
            vncserver_send_framebuffer(client);
            client = vncserver_next_client(client);
        }
    }

    vncserver_cleanup(server);
    free(framebuffer);
    return 0;
}
