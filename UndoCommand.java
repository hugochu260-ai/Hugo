// Undoes the latest undoable command.
public class UndoCommand implements Command {
    private Caretaker caretaker;

    public UndoCommand(Caretaker caretaker) {
        this.caretaker = caretaker;
    }

    @Override
    public boolean execute() {
        caretaker.undo();
        return false;
    }
}
