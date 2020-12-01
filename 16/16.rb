# samples = get_samples('input.txt');
# results = check_samples($operations, samples[0]);
# opmap = determine_opcodes(results[1]);
# execute(opmap, $instruction_map, samples[1]);

Sample = Struct.new(:before, :instruction, :after)

def get_samples(f)
  samples = Array.new
  program = Array.new
  sample = Sample.new
  sampling = true
  empty_lines = 0
  File.readlines(f).each do |line|
    line.strip!
    if sampling
      case line
      when /Before:\s+\[(\d+), (\d+), (\d+), (\d+)\]/
        sample.before = [ $1.to_i, $2.to_i, $3.to_i, $4.to_i ]
        empty_lines = 0
      when /(\d+) (\d+) (\d+) (\d+)/
        sample.instruction = [ $1.to_i, $2.to_i, $3.to_i, $4.to_i ]
        empty_lines = 0
      when /After:\s+\[(\d+), (\d+), (\d+), (\d+)\]/
        sample.after = [ $1.to_i, $2.to_i, $3.to_i, $4.to_i ]
        samples << sample
        sample = Sample.new
        empty_lines = 0
      else
        empty_lines += 1 if line.empty?
        sampling = empty_lines <= 1
      end
    else
      case line
      when /(\d+) (\d+) (\d+) (\d+)/
        program << [ $1.to_i, $2.to_i, $3.to_i, $4.to_i ]
      end
    end
  end
  [ samples, program ]
end

Instruction = Struct.new(:opcode)
class Instruction
  def initialize(opcode)
    super(opcode)
  end
  def apply(registers, a, b, c)
    raise 'unimplemented'
  end
end

$addr = Instruction.new(:addr)
def $addr.apply(registers, a, b, c)
  registers[c] = registers[a] + registers[b]
end

$addi = Instruction.new(:addi)
def $addi.apply(registers, a, b, c)
  registers[c] = registers[a] + b
end

$mulr = Instruction.new(:mulr)
def $mulr.apply(registers, a, b, c)
  registers[c] = registers[a] * registers[b]
end

$muli = Instruction.new(:muli)
def $muli.apply(registers, a, b, c)
  registers[c] = registers[a] * b
end

$banr = Instruction.new(:banr)
def $banr.apply(registers, a, b, c)
  registers[c] = registers[a] & registers[b]
end

$bani = Instruction.new(:bani)
def $bani.apply(registers, a, b, c)
  registers[c] = registers[a] & b
end

$borr = Instruction.new(:borr)
def $borr.apply(registers, a, b, c)
  registers[c] = registers[a] | registers[b]
end

$bori = Instruction.new(:bori)
def $bori.apply(registers, a, b, c)
  registers[c] = registers[a] | b
end

$setr = Instruction.new(:setr)
def $setr.apply(registers, a, b, c)
  registers[c] = registers[a]
end

$seti = Instruction.new(:seti)
def $seti.apply(registers, a, b, c)
  registers[c] = a
end

$gtir = Instruction.new(:gtir)
def $gtir.apply(registers, a, b, c)
  registers[c] = (a > registers[b]) ? 1 : 0
end

$gtri = Instruction.new(:gtri)
def $gtri.apply(registers, a, b, c)
  registers[c] = (registers[a] > b) ? 1 : 0
end

$gtrr = Instruction.new(:gtrr)
def $gtrr.apply(registers, a, b, c)
  registers[c] = (registers[a] > registers[b]) ? 1 : 0
end

$eqir = Instruction.new(:eqir)
def $eqir.apply(registers, a, b, c)
  registers[c] = (a == registers[b]) ? 1 : 0
end

$eqri = Instruction.new(:eqri)
def $eqri.apply(registers, a, b, c)
  registers[c] = (registers[a] == b) ? 1 : 0
end

$eqrr = Instruction.new(:eqrr)
def $eqrr.apply(registers, a, b, c)
  registers[c] = (registers[a] == registers[b]) ? 1 : 0
end

$operations = [ $addr, $addi, $mulr, $muli, $banr, $bani, $borr, $bori, $setr, $seti, $gtir, $gtri, $gtrr, $eqir, $eqri, $eqrr ]
$instruction_map = $operations.to_h { |o| [ o.opcode, o ] }

def check_samples(operations, samples)
  three_plus_opcode_samples = 0
  opmap = Hash.new
  samples.each do |sample|
    possible_opcodes = []
    operations.each do |operation|
      registers = sample.before.clone()
      operation.apply(registers, sample.instruction[1], sample.instruction[2], sample.instruction[3])
      possible_opcodes << operation.opcode if registers == sample.after
    end
    three_plus_opcode_samples += 1 if possible_opcodes.length >= 3
    opcode = sample.instruction[0]
    if opmap[opcode].nil?
      opmap[opcode] = possible_opcodes
    else
      opmap[opcode] = opmap[opcode] & possible_opcodes
    end
  end
  [ three_plus_opcode_samples, opmap ]
end

def determine_opcodes(opmap)
  determined = opmap.values.select { |v| v.length == 1 }
  while determined.length < opmap.values.length
    determined_opcodes = determined.reduce(&:+)
    opmap.each do |k, v|
      if v.length > 1
        opmap[k] = v - determined_opcodes
      end
    end
    determined = opmap.values.select { |v| v.length == 1 }
  end
  opmap.each do |k, v|
    opmap[k] = v[0]
  end
  opmap
end

def execute(opmap, instruction_map, program)
  registers = Array.new(4) { 0 }
  program.each do |instruction|
    opcode = instruction[0]
    instruction_map[opmap[opcode]].apply(registers, instruction[1], instruction[2], instruction[3])
  end
  registers
end
