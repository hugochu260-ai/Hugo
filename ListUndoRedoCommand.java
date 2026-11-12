/**
 * ITP4507 SDFMS
 *
 * Concrete command: print the undo list and the redo list.
 * Listing the history does not change it.
 */
public class ListUndoRedoCommand implements Command {
    private Caretaker caretaker;

    /**
     * @param caretaker the undo and redo history
     */
    public ListUndoRedoCommand(Caretaker caretaker) {
        this.caretaker = caretaker;
    }

    @Override
    public boolean execute() {
        caretaker.list();
        return true;
    }
}
