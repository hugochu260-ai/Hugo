// A menu action. execute returns true only when the action succeeds.
public interface Command {

    boolean execute();
}
