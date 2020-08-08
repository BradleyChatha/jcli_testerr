import std.stdio;
import jaster.cli, jaster.ioc;
import commands;

int main(string[] args)
{
    UserIO.configure
          .useColouredText(true);

    auto runner = new CommandLineInterface!(commands)(new ServiceProvider([
        addFileConfig!(ExampleConfig, AsdfConfigAdapter)("example.json")
    ]));
    return runner.parseAndExecute(args);
}
