// Undo stack and redo stack. A new command clears the redo stack.
import java.util.Stack;

public class Caretaker {
    private Stack<UndoableCommand> undoStack;
    private Stack<UndoableCommand> redoStack;

    public Caretaker() {
        undoStack = new Stack<UndoableCommand>();
        redoStack = new Stack<UndoableCommand>();
    }

    public void record(UndoableCommand command) {
        undoStack.push(command);
        redoStack.clear();
    }

    public boolean undo() {
        if (undoStack.isEmpty()) {
            System.out.println("Nothing to undo!");
            return false;
        }
        UndoableCommand command = undoStack.pop();
        command.undo();
        redoStack.push(command);
        System.out.println("Command (" + command.toString() + ") is undone.");
        return true;
    }

    public boolean redo() {
        if (redoStack.isEmpty()) {
            System.out.println("Nothing to redo!");
            return false;
        }
        UndoableCommand command = redoStack.pop();
        command.redo();
        undoStack.push(command);
        System.out.println("Command (" + command.toString() + ") is redone.");
        return true;
    }

    public void list() {
        System.out.println("Undo List");
        for (int i = 0; i < undoStack.size(); i++) {
            System.out.println(undoStack.get(i).toString());
        }
        System.out.println("-- End of undo list --");
        System.out.println("Redo List");
        for (int i = 0; i < redoStack.size(); i++) {
            System.out.println(redoStack.get(i).toString());
        }
        System.out.println("-- End of redo list --");
    }
}
