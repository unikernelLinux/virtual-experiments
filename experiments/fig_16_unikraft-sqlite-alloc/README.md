# Unikraft SQLite with varying allocators

This experiment provides data for Fig. 16.

## Usage

Run instructions:

```
cd experiments/16_unikraft-sqlite-alloc
./genimages.sh
./benchmark.sh
python3 ./plot.py
```

- `./genimages.sh` takes about 5 minutes in average.
- `./benchmark.sh` takes about 16 minutes in average.