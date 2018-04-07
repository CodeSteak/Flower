# Changelog

## v0.1.4

* replace `Flower.Bloom.(de)serialize` with a `Enumerable` to reduce memory usage
  when saving to disk.
  * add `Flower.Bloom.stream(bloomfilter)`
  * add `Flower.Bloom.from_stream(stream)`
* refactor dirty NIFs to be "clean"
* increase internal max hashes of Bloom Filters from 8 to 16,
  introduce `sha512`.
* include CHANGELOG

## v0.1.3

* rename `Flower.Bloom.has_maybe?` to `Flower.Bloom.has?`

## v0.1.2

* fix hex package setup

## v0.1.1

* flag `Flower.Bloom.serialize` as experimental
* flag `Flower.Bloom.deserialize` as experimental
* initial version
