#include <mach/mach.h>
#include <mach/mach_time.h>
#include <rfb/keysym.h>
#include <IOKit/hidsystem/IOHIDUsageTables.h>

extern "C" {
    typedef uint32_t IOHIDEventOptionBits;
    typedef struct __IOHIDEvent *IOHIDEventRef;
    typedef struct CF_BRIDGED_TYPE(id) __IOHIDEventSystemClient * IOHIDEventSystemClientRef;
    IOHIDEventRef IOHIDEventCreateKeyboardEvent(
        CFAllocatorRef allocator,
        uint64_t time, uint16_t page, uint16_t usage,
        Boolean down, IOHIDEventOptionBits flags
    );

    // IOHIDEventRef IOHIDEventCreateDigitizerEvent(CFAllocatorRef allocator, uint64_t timeStamp, IOHIDDigitizerTransducerType type, uint32_t index, uint32_t identity, uint32_t eventMask, uint32_t buttonMask, IOHIDFloat x, IOHIDFloat y, IOHIDFloat z, IOHIDFloat tipPressure, IOHIDFloat barrelPressure, Boolean range, Boolean touch, IOOptionBits options);
    // IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(CFAllocatorRef allocator, uint64_t timeStamp, uint32_t index, uint32_t identity, uint32_t eventMask, IOHIDFloat x, IOHIDFloat y, IOHIDFloat z, IOHIDFloat tipPressure, IOHIDFloat twist, Boolean range, Boolean touch, IOOptionBits options);

    IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);

    // void IOHIDEventAppendEvent(IOHIDEventRef parent, IOHIDEventRef child);
    // void IOHIDEventSetIntegerValue(IOHIDEventRef event, IOHIDEventField field, int value);
    void IOHIDEventSetSenderID(IOHIDEventRef event, uint64_t sender);

    void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);
    // void IOHIDEventSystemConnectionDispatchEvent(IOHIDEventSystemConnectionRef connection, IOHIDEventRef event);
}

static void VNCSendHIDEvent(IOHIDEventRef event) {
    static IOHIDEventSystemClientRef client_(NULL);
    if (client_ == NULL)
        client_ = IOHIDEventSystemClientCreate(kCFAllocatorDefault);

    IOHIDEventSetSenderID(event, 0xDEFACEDBEEFFECE5);
    IOHIDEventSystemClientDispatchEvent(client_, event);
    CFRelease(event);
}

static void VNCKeyboard(rfbBool down, rfbKeySym key, rfbClientPtr client) {
    uint16_t usage;

    switch (key) {
        case XK_exclam: case XK_1: usage = kHIDUsage_Keyboard1; break;
        case XK_at: case XK_2: usage = kHIDUsage_Keyboard2; break;
        case XK_numbersign: case XK_3: usage = kHIDUsage_Keyboard3; break;
        case XK_dollar: case XK_4: usage = kHIDUsage_Keyboard4; break;
        case XK_percent: case XK_5: usage = kHIDUsage_Keyboard5; break;
        case XK_asciicircum: case XK_6: usage = kHIDUsage_Keyboard6; break;
        case XK_ampersand: case XK_7: usage = kHIDUsage_Keyboard7; break;
        case XK_asterisk: case XK_8: usage = kHIDUsage_Keyboard8; break;
        case XK_parenleft: case XK_9: usage = kHIDUsage_Keyboard9; break;
        case XK_parenright: case XK_0: usage = kHIDUsage_Keyboard0; break;

        case XK_A: case XK_a: usage = kHIDUsage_KeyboardA; break;
        case XK_B: case XK_b: usage = kHIDUsage_KeyboardB; break;
        case XK_C: case XK_c: usage = kHIDUsage_KeyboardC; break;
        case XK_D: case XK_d: usage = kHIDUsage_KeyboardD; break;
        case XK_E: case XK_e: usage = kHIDUsage_KeyboardE; break;
        case XK_F: case XK_f: usage = kHIDUsage_KeyboardF; break;
        case XK_G: case XK_g: usage = kHIDUsage_KeyboardG; break;
        case XK_H: case XK_h: usage = kHIDUsage_KeyboardH; break;
        case XK_I: case XK_i: usage = kHIDUsage_KeyboardI; break;
        case XK_J: case XK_j: usage = kHIDUsage_KeyboardJ; break;
        case XK_K: case XK_k: usage = kHIDUsage_KeyboardK; break;
        case XK_L: case XK_l: usage = kHIDUsage_KeyboardL; break;
        case XK_M: case XK_m: usage = kHIDUsage_KeyboardM; break;
        case XK_N: case XK_n: usage = kHIDUsage_KeyboardN; break;
        case XK_O: case XK_o: usage = kHIDUsage_KeyboardO; break;
        case XK_P: case XK_p: usage = kHIDUsage_KeyboardP; break;
        case XK_Q: case XK_q: usage = kHIDUsage_KeyboardQ; break;
        case XK_R: case XK_r: usage = kHIDUsage_KeyboardR; break;
        case XK_S: case XK_s: usage = kHIDUsage_KeyboardS; break;
        case XK_T: case XK_t: usage = kHIDUsage_KeyboardT; break;
        case XK_U: case XK_u: usage = kHIDUsage_KeyboardU; break;
        case XK_V: case XK_v: usage = kHIDUsage_KeyboardV; break;
        case XK_W: case XK_w: usage = kHIDUsage_KeyboardW; break;
        case XK_X: case XK_x: usage = kHIDUsage_KeyboardX; break;
        case XK_Y: case XK_y: usage = kHIDUsage_KeyboardY; break;
        case XK_Z: case XK_z: usage = kHIDUsage_KeyboardZ; break;

        case XK_underscore: case XK_minus: usage = kHIDUsage_KeyboardHyphen; break;
        case XK_plus: case XK_equal: usage = kHIDUsage_KeyboardEqualSign; break;
        case XK_braceleft: case XK_bracketleft: usage = kHIDUsage_KeyboardOpenBracket; break;
        case XK_braceright: case XK_bracketright: usage = kHIDUsage_KeyboardCloseBracket; break;
        case XK_bar: case XK_backslash: usage = kHIDUsage_KeyboardBackslash; break;
        case XK_colon: case XK_semicolon: usage = kHIDUsage_KeyboardSemicolon; break;
        case XK_quotedbl: case XK_apostrophe: usage = kHIDUsage_KeyboardQuote; break;
        case XK_asciitilde: case XK_grave: usage = kHIDUsage_KeyboardGraveAccentAndTilde; break;
        case XK_less: case XK_comma: usage = kHIDUsage_KeyboardComma; break;
        case XK_greater: case XK_period: usage = kHIDUsage_KeyboardPeriod; break;
        case XK_question: case XK_slash: usage = kHIDUsage_KeyboardSlash; break;

        case XK_Return: usage = kHIDUsage_KeyboardReturnOrEnter; break;
        case XK_BackSpace: usage = kHIDUsage_KeyboardDeleteOrBackspace; break;
        case XK_Tab: usage = kHIDUsage_KeyboardTab; break;
        case XK_space: usage = kHIDUsage_KeyboardSpacebar; break;

        case XK_Shift_L: usage = kHIDUsage_KeyboardLeftShift; break;
        case XK_Shift_R: usage = kHIDUsage_KeyboardRightShift; break;
        case XK_Control_L: usage = kHIDUsage_KeyboardLeftControl; break;
        case XK_Control_R: usage = kHIDUsage_KeyboardRightControl; break;
        case XK_Meta_L: usage = kHIDUsage_KeyboardLeftAlt; break;
        case XK_Meta_R: usage = kHIDUsage_KeyboardRightAlt; break;
        case XK_Alt_L: usage = kHIDUsage_KeyboardLeftGUI; break;
        case XK_Alt_R: usage = kHIDUsage_KeyboardRightGUI; break;

        case XK_Up: usage = kHIDUsage_KeyboardUpArrow; break;
        case XK_Down: usage = kHIDUsage_KeyboardDownArrow; break;
        case XK_Left: usage = kHIDUsage_KeyboardLeftArrow; break;
        case XK_Right: usage = kHIDUsage_KeyboardRightArrow; break;

        case XK_Home: case XK_Begin: usage = kHIDUsage_KeyboardHome; break;
        case XK_End: usage = kHIDUsage_KeyboardEnd; break;
        case XK_Page_Up: usage = kHIDUsage_KeyboardPageUp; break;
        case XK_Page_Down: usage = kHIDUsage_KeyboardPageDown; break;

        default: return;
    }

    VNCSendHIDEvent(IOHIDEventCreateKeyboardEvent(kCFAllocatorDefault, mach_absolute_time(), kHIDPage_KeyboardOrKeypad, usage, down, 0));
}

static void handleVNCKeyboard(rfbBool down, rfbKeySym key, rfbClientPtr client) {
    NSLog(@"sharat d:%u k:%04x", down, key);
    VNCKeyboard(down, key, client);
}
