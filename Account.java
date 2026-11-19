public class Account {
    private String accountNumber;
    private double balance;

    public Account(String accountNumber, double balance) {
        this.accountNumber = accountNumber;
        this.balance = balance;
    }

    public String getAccountNumber() {
        return accountNumber;
    }

    public double getBalance() {
        return balance;
    }

    void setBalance(double balance) {
        this.balance = balance;
    }

    public void increase(double amount) {
        balance += amount;
        System.out.println("--- account no: " + accountNumber + " increase amount: " + amount);
    }

    public void decrease(double amount) {
        balance -= amount;
        System.out.println("--- account no: " + accountNumber + " decrease amount: " + amount);
    }
}
