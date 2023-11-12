import { json } from "@sveltejs/kit";
import { SerialPort } from "serialport";

const COMPORT = 4;
const baudRate = 9600;
const newLine = "\n";

let queue: Buffer[] = [];
// const port = new SerialPort({ path: `\\\\.\\COM${COMPORT}`, baudRate: baudRate });

//port.on("readable", function () {
//    queue.push(port.read());
//})

export function GET() {
    if (queue.length === 0) {
        return json({ bytes: "" });
    }

    let data = queue.shift();
    return json({ bytes: data?.toString() });
}

export async function POST({ request }) {
    const { cmd } = await request.json();

    // port.write(cmd + newLine);

	return json({ status: 201 });
}
