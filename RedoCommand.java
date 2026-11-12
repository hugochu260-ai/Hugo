/**
 * ITP4507 SDFMS
 *
 * Concrete command: redo the most recently undone command.
 * Redo itself is not an {@link UndoableCommand}.
 */
public class RedoCommand implements Command {
    private Caretaker caretaker;

    /**
     * @param caretaker the undo and redo history
     */
    public RedoCommand(Caretaker caretaker) {
        this.caretaker = caretaker;
    }

    @Override
    public boolean execute() {
        caretaker.redo();
        return false;
    }
}
