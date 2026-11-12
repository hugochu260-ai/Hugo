// Redoes the latest undone command.
public class RedoCommand implements Command {
    private Caretaker caretaker;

    public RedoCommand(Caretaker caretaker) {
        this.caretaker = caretaker;
    }

    @Override
    public boolean execute() {
        caretaker.redo();
        return false;
    }
}
