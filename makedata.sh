rm -rf /tmp/data
mkdir -p /tmp/data/data1
mkdir -p /tmp/data/data2
echo "abc123" > /tmp/data/data1/abc
echo "abc123" > /tmp/data/data2/abc
echo "def123" > /tmp/data/data2/def
ln /tmp/data/data2/def /tmp/data/data1/def
echo "ghi123" > /tmp/data/data1/ghi
echo "xyz" > /tmp/data/data1/xyz
