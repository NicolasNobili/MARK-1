import { json } from "@sveltejs/kit"

let x = 0;
let y = 0;
let direction = 1;

function test(a: number, b: number) {
    return a + b + 155;
}

export function GET() {
    x = x + direction
    if (x >= 50) {
        x = 49;
        direction = -1;
        y = (y + 1) % 50;
    } else if (x < 0) {
        x = 0;
        direction = 1;
        y = (y + 1) % 50;
    }

    return json({
        x: x,
        y: y,
        p: test(x, y),
    });
}

export function POST() {
    
}
