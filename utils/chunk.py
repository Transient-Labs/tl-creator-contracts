import sys
import json


def split_into_chunks(content, chunk_size):
    chunks = []
    for i in range(0, len(content), chunk_size):
        chunk = content[i : i + chunk_size]
        chunks.append(chunk)
    return chunks


def process_file(input_file, output_file, chunk_size):
    with open(input_file, "r") as file:
        content = file.read()

    chunks = split_into_chunks(content, chunk_size)

    with open(output_file, "w") as file:
        json.dump(chunks, file)


# Usage example:
# python script.py input.txt output.json 19600
chunk_size = 19600

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    process_file(input_file, output_file, chunk_size)
