/**
 * Command participant in the Command pattern.
 * <p>
 * Every menu operation is a command object. Undoable commands also know how
 * to reverse and replay themselves, so the caretaker can store the command
 * rather than a separate inverse action.
 * </p>
 */
public interface Command {

    /**
     * Runs the command, reading any further input it needs.
     *
     * @return {@code true} when the command completed and changed state
     */
    boolean execute();

    /** Reverses a previously successful {@link #execute()}. */
    void undo();

    /** Replays a command that was undone. */
    void redo();

    /**
     * @return {@code true} when a successful execution should be kept for undo
     */
    boolean isUndoable();

    /**
     * Short description used by the undo list, the redo list, and the
     * undo/redo confirmation messages. Fixed when the command is executed.
     */
    String getRecord();
}
