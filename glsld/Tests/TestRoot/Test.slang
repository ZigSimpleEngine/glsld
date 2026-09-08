#version 450
layout(location = 0) out vec4 FragColor;

public struct MyStruct {
	__init(int x) {
        this.x = x;
	}

    MyStruct operator+(MyStruct rhs) {
        return MyStruct(x + rhs.x);
	}

    public int MyFunc() {
        return x;
	}

	private int x;
};

namespace std::aa {
	int a;
}

void main() {
    using std;
    aa::a = 10;
    FragColor = vec4(1.0);
    let ms = MyStruct(10);
}