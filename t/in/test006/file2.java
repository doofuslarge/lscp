class HelloWorldApp2 {
    public static void main(String[] args) {
        int ident1 = 0;
        int ident2 = 1000;
        if (0 == 1){
        System.out.println("Hello World!"); 
        }
    }
    // These comments should be kept. What about keywords like int?
    private static int otherFunction(int foo, int bar){
        System.out.println("Another string, now with int inside!"); 
        return foo+bar;
    }
}
