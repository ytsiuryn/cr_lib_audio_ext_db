test:
	crystal spec
benchmark:
	# --mcpu=native
	crystal build --release --no-debug benchmarks/speed/musicbrainz_benchmark.cr -o bin/musicbrainz_bench
	crystal build --release --no-debug benchmarks/speed/discogs_benchmark.cr -o bin/discogs_bench
	sudo cpupower frequency-set -g performance
	./bin/musicbrainz_bench
	./bin/discogs_bench
	sudo cpupower frequency-set -g powersave
