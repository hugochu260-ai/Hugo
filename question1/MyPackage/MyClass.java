package MyPackage;

public class MyClass {
    private int state;

    public MyClass() {
        state = 1;
    }

    public int getState() {
        return state;
    }

    void setState(int state) {
        this.state = state;
    }

    public void doAction() {
        state++;
    }
}
