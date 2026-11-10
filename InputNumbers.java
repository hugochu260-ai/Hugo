/**
 * Parses integers typed at the menu without throwing into the command flow.
 */
public final class InputNumbers {

    private InputNumbers() {
    }

    /**
     * @return the parsed value, or {@code null} when {@code text} is not an integer
     */
    public static Integer parseInt(String text) {
        if (text == null) {
            return null;
        }
        try {
            return Integer.valueOf(text.trim());
        } catch (NumberFormatException ex) {
            return null;
        }
    }
}
