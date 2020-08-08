module commands;

import std.experimental.logger : LogLevel;
import jaster.cli;

@Command("logging", "Shows all logging colours.")
struct DefaultCommand
{
    @CommandNamedArg("v|verbose", "Show verbose logging.")
    Nullable!bool verbose;

    @CommandNamedArg("l|min-log-level", "Sets the minimum log level.")
    Nullable!LogLevel logLevel;

    @CommandNamedArg("no-colour", "Disables coloured logging.")
    Nullable!bool noColour;

    void onExecute()
    {
        UserIO.configure()
              .useVerboseLogging(this.verbose.get(false))
              .useMinimumLogLevel(this.logLevel.get(LogLevel.all))
              .useColouredText(!(noColour.get(false)));

        UserIO.logTracef       ("This is a trace log.");
        UserIO.logInfof        ("This is an info log.");
        UserIO.logWarningf     ("This is a warning log.");
        UserIO.logErrorf       ("This is an error log.");
        UserIO.logCriticalf    ("This is a critical log.");

        UserIO.verboseTracef   ("This is a verbose trace log.");
        UserIO.verboseInfof    ("This is a verbose info log.");
        UserIO.verboseWarningf ("This is a verbose warning log.");
        UserIO.verboseErrorf   ("This is a verbose error log.");
        UserIO.verboseCriticalf("This is a verbose critical log.");
    }
}

struct ExampleConfig
{
    string name;
}

@Command("name set", "Sets the name in the config file.")
struct NameSetCommand
{
    @CommandPositionalArg(0)
    string name;

    private IConfig!ExampleConfig _config;

    this(IConfig!ExampleConfig config)
    {
        this._config = config;
    }

    void onExecute()
    {
        auto config = this._config.value;
        config.name = this.name;
        this._config.value = config;
        this._config.save();
    }
}

@Command("name get", "Gets the name in the config file.")
struct NameGetCommand
{
    private IConfig!ExampleConfig _config;

    this(IConfig!ExampleConfig config)
    {
        this._config = config;
    }

    void onExecute()
    {
        UserIO.logInfof("The name in the config file is: %s", this._config.value.name);
    }
}

@Command("ansi", "Shows all ansi styles.")
struct AnsiCommand
{
    @CommandNamedArg("mark-unsupported")
    Nullable!bool markUnsupported;

    void onExecute()
    {
        UserIO.logInfof("Bold!".ansi.bold.toString());
        UserIO.logInfof("Underline!".ansi.underline.toString());
        UserIO.logInfof("Invert!".ansi.invert.toString());

        if(this.markUnsupported.get(false))
            UserIO.logWarningf("\nThe following styles aren't widely supported:\n");

        UserIO.logInfof("Dim!".ansi.dim.toString());
        UserIO.logInfof("Italic!".ansi.italic.toString());
        UserIO.logInfof("Strike!".ansi.strike.toString());
        UserIO.logInfof("Slow Blink!".ansi.slowBlink.toString());
        UserIO.logInfof("Fast Blink!".ansi.fastBlink.toString());
    }
}

@Command("echo", "Raw list test")
struct EchoCommand
{
    @CommandRawArg
    string[] rawList;

    void onExecute()
    {
        UserIO.logInfof("%s", this.rawList);
    }
}

@Command("benchmark buffer", "Runs benchmarks for TextBuffer")
struct BufferBenchmarkCommand
{
    @CommandNamedArg("runs|r", "How many times to run the function.")
    Nullable!uint runs;

    @CommandNamedArg("width|w", "How wide the TextBuffer is.")
    Nullable!size_t width;

    @CommandNamedArg("height", "How high the TextBuffer is.")
    Nullable!size_t height;

    void onExecute()
    {
        import core.memory;
        import std.datetime.stopwatch : benchmark;
        import std.stdio;
        import jaster.cli;

        const RUN_N  = this.runs.get(1_000);
        const WIDTH  = this.width.get(180);
        const HEIGHT = this.height.get(180);

        auto sharedBuffer = new TextBuffer(WIDTH, HEIGHT);
        TextBuffer[] semiSharedBuffers;

        foreach(i; 0..3)
            semiSharedBuffers ~= new TextBuffer(WIDTH, HEIGHT);

        const durations = benchmark!(
            () => worstCase(sharedBuffer, WIDTH, HEIGHT),
            () => bestishCase(sharedBuffer, WIDTH, HEIGHT),
            () => everyLineIsASequence(sharedBuffer, WIDTH, HEIGHT),

            () => worstCase(semiSharedBuffers[0], WIDTH, HEIGHT),
            () => bestishCase(semiSharedBuffers[1], WIDTH, HEIGHT),
            () => everyLineIsASequence(semiSharedBuffers[2], WIDTH, HEIGHT),

            () => worstCase(new TextBuffer(WIDTH, HEIGHT) , WIDTH, HEIGHT),
            () => bestishCase(new TextBuffer(WIDTH, HEIGHT), WIDTH, HEIGHT),
            () => everyLineIsASequence(new TextBuffer(WIDTH, HEIGHT), WIDTH, HEIGHT),
            () => onlyWrite(new TextBuffer(WIDTH, HEIGHT), WIDTH, HEIGHT)
        )(RUN_N);

        void report(string name, string meta, size_t durationIndex)
        {
            writefln("[%s | %s] ran %s times -> %s -> AVERAGING -> %s", name, meta, RUN_N, durations[durationIndex], durations[durationIndex] / RUN_N);
        }

        report("WORST CASE  ", "SHARED  ", 0);
        report("BESTISH CASE", "SHARED  ", 1);
        report("EVERY LINE  ", "SHARED  ", 2);
        report("WORST CASE  ", "SEMI    ", 3);
        report("BESTISH CASE", "SEMI    ", 4);
        report("EVERY LINE  ", "SEMI    ", 5);
        report("WORST CASE  ", "UNIQUE  ", 6);
        report("BESTISH CASE", "UNIQUE  ", 7);
        report("EVERY LINE  ", "UNIQUE  ", 8);
        report("WRITE ONLY  ", "SPECIAL ", 9);
    }

    void worstCase(TextBuffer buffer, size_t width, size_t height)
    {
        auto writer = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

        const a = AnsiTextFlags.bold;
        const b = AnsiTextFlags.none;
        bool useA = true;
        foreach(y; 0..height)
        {
            foreach(x; 0..width)
            {
                writer.flags = (useA) ? a : b;
                useA = !useA;

                writer.set(x, y, '0');
            }
        }
        
        buffer.toString();
    }

    void bestishCase(TextBuffer buffer, size_t width, size_t height)
    {
        auto writer = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

        foreach(y; 0..height)
        {
            foreach(x; 0..width)
                writer.set(x, y, '0');
        }

        buffer.toString();
    }

    void everyLineIsASequence(TextBuffer buffer, size_t width, size_t height)
    {
        auto writer = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

        const a = AnsiTextFlags.bold;
        const b = AnsiTextFlags.none;
        bool useA = true;
        foreach(y; 0..height)
        {
            writer.flags = (useA) ? a : b;
            useA = !useA;
            foreach(x; 0..width)
                writer.set(x, y, '0');
        }

        buffer.toString();
    }

    void onlyWrite(TextBuffer buffer, size_t width, size_t height)
    {
        auto writer = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);
        foreach(y; 0..height)
        {
            foreach(x; 0..width)
                writer.set(x, y, '0');
        }
    }
}

@Command("buffer table", "Shows a table made using TextBuffer")
struct BufferTableCommand
{
    void onExecute()
    {
        auto options = TextBufferOptions(TextBufferLineMode.addNewLine);
        auto buffer  = new TextBuffer(80, 7, options);
        auto writer  = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

        const ALL = TextBuffer.USE_REMAINING_SPACE; // Easier to read.
        alias AC  = AnsiColour;  // To get around some weird behaviour that the `with` statement is causing.
        alias AF  = AnsiTextFlags; // ditto
        with(writer) with(AF)
        {
            // Create all the borders in green.
            fg = AC(Ansi4BitColour.green);
            fill(0,     0,      ALL,    ALL,    ' '); // Every character defaults to space
            fill(0,     0,      ALL,    1,      '#'); // Top horizontal border
            fill(0,     2,      ALL,    1,      '='); // Horizontal border under column names
            fill(0,     4,      ALL,    1,      '-'); // Horizontal border under values
            fill(0,     1,      1,      ALL,    '|'); // Left-most vertical border
            fill(79,    1,      1,      ALL,    '|'); // Right-most vertical border
            fill(21,    1,      1,      ALL,    '|'); // Vertical border after Name column
            fill(36,    1,      1,      ALL,    '|'); // Vertical border after Age column
            fill(0,     6,      ALL,    1,      '#'); // Bottom horizontal border

            // Create seperate writers (very cheap) to easily confine and calculate the space we work with.
            // The fluent interface makes this less cumbersome than it'd otherwise be.
            buffer.createWriter(2, 1, 20, 5)
                  .write(7, 0, "Name")
                  .write(1, 2, "Bradley".ansi.fg(Ansi4BitColour.red))
                  .write(1, 4, "Andy".ansi.fg(Ansi4BitColour.blue));
            buffer.createWriter(23, 1, 13, 5)
                  .write(5, 0, "Age")
                  .fg(AC(Ansi4BitColour.brightBlue))
                  .flags(underline | bold) // Because of the AnsiTextFlags `with` statement.
                  .write(1, 2, "21")
                  .write(1, 4, "200");
            buffer.createWriter(38, 1, 51, 5)
                  .write(14, 0, "Description")
                  .fg(AC(Ansi4BitColour.magenta))
                  .write(1,  2, "Hates being alive.")
                  .write(1,  4, "Andy + clones = rule world");
        
            UserIO.logInfof(buffer.toString());
        }
    }
}

@Command("rainbow logo", "Shows a rainbow JCLI logo")
struct RainbowLogoCommand
{
    // Taken from Arsd.colour, so I don't need the entire module just for this function.
    //
    // Licensed under: http://www.boost.org/LICENSE_1_0.txt
    AnsiRgbColour fromHsl(double h, double s, double l, double a = 255) nothrow pure @safe @nogc {
        h = h % 360;

        nothrow @safe @nogc pure
	    double absInternal(double a) { return a < 0 ? -a : a; }

        double C = (1 - absInternal(2 * l - 1)) * s;

        double hPrime = h / 60;

        double X = C * (1 - absInternal(hPrime % 2 - 1));

        double r, g, b;

        if(h is double.nan)
            r = g = b = 0;
        else if (hPrime >= 0 && hPrime < 1) {
            r = C;
            g = X;
            b = 0;
        } else if (hPrime >= 1 && hPrime < 2) {
            r = X;
            g = C;
            b = 0;
        } else if (hPrime >= 2 && hPrime < 3) {
            r = 0;
            g = C;
            b = X;
        } else if (hPrime >= 3 && hPrime < 4) {
            r = 0;
            g = X;
            b = C;
        } else if (hPrime >= 4 && hPrime < 5) {
            r = X;
            g = 0;
            b = C;
        } else if (hPrime >= 5 && hPrime < 6) {
            r = C;
            g = 0;
            b = X;
        }

        double m = l - C / 2;

        r += m;
        g += m;
        b += m;

        return AnsiRgbColour(
            cast(ubyte)(r * 255),
            cast(ubyte)(g * 255),
            cast(ubyte)(b * 255));
    }

    @CommandNamedArg("fps", "How many frames to run at")
    Nullable!uint fps;

    void onExecute()
    {
        import core.thread   : Thread;
        import core.time     : msecs;
        import std.algorithm : splitter;
        import std.range     : walkLength;
        const art = `_________ _______  _       _________
\__    _/(  ____ \( \      \__   __/
   )  (  | (    \/| (         ) (   
   |  |  | |      | |         | |   
   |  |  | |      | |         | |   
   |  |  | |      | |         | |   
|\_)  )  | (____/\| (____/\___) (___
(____/   (_______/(_______/\_______/`;

        auto  lines      = art.splitter('\n');
        const lineLength = lines.front.length;
        const lineCount  = lines.walkLength;

        auto buffer = new TextBuffer(lineLength, lineCount, TextBufferOptions(TextBufferLineMode.addNewLine));
        auto writer = buffer.createWriter(0, 0, TextBuffer.USE_REMAINING_SPACE, TextBuffer.USE_REMAINING_SPACE);

        const RAINBOW_STEPS = lineCount;
        const HUE_PER_STEP  = 360 / RAINBOW_STEPS;
        auto  hue           = 0;
        while(true)
        {
            size_t currentLine;
            foreach(line; lines)
            {
                writer.fg(AnsiColour(this.fromHsl(hue, 0.5, 0.5)));
                writer.write(0, currentLine, line);
                currentLine++;
                hue += HUE_PER_STEP;
            }

            UserIO.logInfof(buffer.toStringNoDupe());
            UserIO.moveCursorUpByLines(lineCount);
            Thread.sleep((1000 / this.fps.get(5)).msecs);
            hue += HUE_PER_STEP;
        }
    }
}