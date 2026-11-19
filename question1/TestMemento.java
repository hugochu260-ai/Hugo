import MyPackage.*;

public class TestMemento {
    public static void main(String args[]) {
        Caretaker ct = new Caretaker();
        MyClass mc = new MyClass();
        System.out.println("Create a my class object with state 1");
        System.out.println("Current state : " + mc.getState());
        ct.saveMyClass(mc);
        mc.doAction();
        System.out.println("Change my class object to state 2");
        System.out.println("Current state : " + mc.getState());
        ct.saveMyClass(mc);
        mc.doAction();
        System.out.println("Change my class object to state 3");
        System.out.println("Current state : " + mc.getState());
        ct.saveMyClass(mc);
        mc.doAction();
        System.out.println("Change my class object to state 4");
        System.out.println("Current state : " + mc.getState());
        ct.undo();
        System.out.println("Perform undo");
        System.out.println("Current state : " + mc.getState());
        ct.undo();
        System.out.println("Perform undo");
        System.out.println("Current state : " + mc.getState());
    }
}
