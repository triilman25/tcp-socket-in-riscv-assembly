AS := as
LD := ld

OBJ_FILES = website.o

website: $(OBJ_FILES)
	$(LD) $^ -o $@

$(OBJ_FILES):%.o: %.s
	$(AS) $? -o $@

clean:
	rm -f $(OBJ_FILES) website

run:
	uname -a
	file website
	./website


