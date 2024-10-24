echo V1 > toto.txt

./version.sh rm toto.txt
./version.sh add toto.txt 'V1'

for i in $(seq 2 120); do
	echo V$i > toto.txt
	./version.sh commit toto.txt 'V'$i''
done

echo Done