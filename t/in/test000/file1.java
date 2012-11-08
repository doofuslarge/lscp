/* This multi-line comment
should not appear
in the final output.
*/
class HelloWorldApp2 {
    public static void main(String[] args) {
        int ident1 = 0;
        int ident2 = 1000;
        if (0 == 1){
            System.out.println("Hello World!"); 
        }
    }
    // These comments should not be kept. 
    private static int otherFunction(int foo, int bar){
        System.out.println("Another string, now with int inside!"); 
        return foo+bar;
    }
}
