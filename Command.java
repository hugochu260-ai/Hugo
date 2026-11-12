/**
 * ITP4507 SDFMS
 *
 * Command. Every menu action except exit is a command.
 * {@link #execute()} returns true only when the action really finished.
 * A failed action (unknown id, invalid role, and so on) returns false
 * and is not put on the undo list.
 */
public interface Command {
    /**
     * Performs the action, including any prompts it needs.
     *
     * @return {@code true} when the action finished successfully
     */
    boolean execute();
}
