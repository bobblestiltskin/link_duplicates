rm -rf /tmp/data
mkdir -p /tmp/data/data1 /tmp/data/data2 /tmp/data/data3 /tmp/data/data4
echo "abc123" > /tmp/data/data1/abc
echo "abc123" > /tmp/data/data2/abc
echo "abc123" > /tmp/data/data3/abc
echo "abc123" > /tmp/data/data4/abc
echo "def123" > /tmp/data/data2/def
ln /tmp/data/data2/def /tmp/data/data1/def
ln /tmp/data/data2/def /tmp/data/data3/def
echo "ghi123" > /tmp/data/data1/ghi
echo "ghi123" > /tmp/data/data4/ghi
echo "jkl123" > /tmp/data/data3/jkl
echo "xyz" > /tmp/data/data1/xyz
