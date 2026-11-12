/**
 * ITP4507 SDFMS
 *
 * Concrete command: undo the most recent undoable command.
 * Undo itself is not an {@link UndoableCommand}.
 */
public class UndoCommand implements Command {
    private Caretaker caretaker;

    /**
     * @param caretaker the undo and redo history
     */
    public UndoCommand(Caretaker caretaker) {
        this.caretaker = caretaker;
    }

    @Override
    public boolean execute() {
        caretaker.undo();
        return false;
    }
}
