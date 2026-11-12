// A command that can be undone and redone. toString is the history line.
public interface UndoableCommand extends Command {

    void undo();

    void redo();

    String toString();
}
