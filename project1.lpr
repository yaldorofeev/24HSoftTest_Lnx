program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, CustApp, syncobjs;

type
  TToWrite = record
    order: Integer;
    prime: Integer;
  end;

type
  TMyApplication = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

  // Thraed class that finds primes and writes them to files. The Erathothfen metod was used.
type
  TPrimeWriter = class(TThread)
  private
    FOwnFile: TextFile;
  protected
    procedure Execute; override;
  public
    FOwnPrimeCount: Integer;
    FOwnTime: double;
    FFileName: string;
  end;

var
  Application: TMyApplication;
  n: Integer;

  // Critical section for data sharing
  CSGlobeI: TCriticalSection;

  // Critical section for "Result" file accsess.
  CSWrite: TCriticalSection;

  CommonFile: TextFile;
  WriteThreads: array of TPrimeWriter;
  ThreadsCount: Integer;
  ii: Integer;
  a: array of integer;
  globI: Integer;
  LastWrote: Integer;
  foundCount: Integer;
  S: string;


procedure TPrimeWriter.Execute;
var
  i, j, k: integer;
  toWrite: Integer;
  toWrites: array of TToWrite;
  LFC: Integer;
  Fr,Sta,Sto: int64;
begin
  AssignFile(FOwnFile, FFileName);
  ReWrite(FOwnFile);
  Closefile(FOwnFile);
  FOwnPrimeCount := 0;

  Sta := GetTickCount64;

  while (globI < n  + 1) or (Length(toWrites) > 0) do
    begin

      if globI < n  + 1 then
        begin
          CSGlobeI.Enter;
          i:= globI;
          globI:= globI + 1;

          if a[i] <> 0 then
            begin
              FOwnPrimeCount := FOwnPrimeCount + 1;
              foundCount := foundCount + 1;
              LFC := foundCount;
              toWrite := a[i];
              j := i;
              while j < n + 1 do
                begin
                  a[j] := 0;
                  j := j + i;
                end;
              CSGlobeI.Leave;

              // Write to thread*.txt
              Append(FOwnFile);
              Write(FOwnFile, inttostr(toWrite) + ' ');
              Closefile(FOwnFile);

              // Queue toWrites.
              SetLength(toWrites, Length(toWrites) + 1);
              toWrites[Length(toWrites) - 1].order := LFC;
              toWrites[Length(toWrites) - 1].prime := toWrite;
            end
          else CSGlobeI.Leave;
        end;

      // Write to Result.txt from toWrites queue.
      for j:=0 to Length(toWrites) - 1 do
        begin
          if toWrites[j].order = LastWrote then
            begin

              CSWrite.Enter;
              Append(CommonFile);
              Write(CommonFile, inttostr(toWrites[j].prime) + ' ');
              Closefile(CommonFile);
              LastWrote := toWrites[j].order + 1;
              CSWrite.Leave;

              // Dequeue toWrites.
              if Length(toWrites) > 1 then
                begin
                  for k := 1 to Length(toWrites) - 1 do
                    begin
                      toWrites[k - 1] := toWrites[k]
                    end;
                end;
              SetLength(toWrites, Length(toWrites) - 1);
            end
          else break;
        end;
    end;
  Sto := GetTickCount64;
  FOwnTime := Sto-Sta;
end;

{ TMyApplication }

procedure TMyApplication.DoRun;
var
  ErrorMsg: String;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions('h', 'help');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  { add your program here }

  // stop program loop
  Terminate;
end;

constructor TMyApplication.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TMyApplication.Destroy;
begin
  inherited Destroy;
end;

procedure TMyApplication.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ', ExeName, ' -h');
end;


begin
  Writeln('sss');
  Application:=TMyApplication.Create(nil);
  Application.Title:='My Application';
  Application.Run;
  Writeln('Please enter bound of prime numbers search as an unsigned integer:');
  while True do
    begin
      try
        ReadLn(n);
        if n > 0 then Break else Writeln('It is not an unsigned integer. Try again.');
      except
        Writeln('It is not an integer. Try again.');
      end;
    end;

  Writeln('Please enter number of threads. The number must not be greater than 4.');
  while True do
    begin
      try
        ReadLn(ThreadsCount);
        if  ThreadsCount <= 4 then
          begin
            if  ThreadsCount > 1 then  Break else Writeln('The number less than 1. Try again.');
          end
        else  Writeln('The number greater than 4. Try again.');
      except
        Writeln('It is not an unsigned integer. Try again.');
      end;
    end;

  Writeln('begin culculating');
  SetLength(a, n + 1);

  a[0] := 0;
  a[1] := 0;
  for ii := 2 to n do
    begin
      a[ii] := ii;
    end;

  {$I-}
  AssignFile(CommonFile, 'Result.txt');
  ReWrite(CommonFile);
  {$I+}

  CSGlobeI := TCriticalSection.Create();
  CSWrite := TCriticalSection.Create();
  SetLength(WriteThreads, ThreadsCount);
  globI := 2;
  LastWrote := 1;
  foundCount := 0;

  //Lounching threads
  for ii:=0 to ThreadsCount - 1 do
    begin
      WriteThreads[ii] := TPrimeWriter.Create(true);
      WriteThreads[ii].FFileName := Format('Thread%d.txt', [ii + 1]);
      WriteThreads[ii].Start;
    end;

  //Waiting for threads will be stopped
  for ii:=0 to ThreadsCount - 1 do
    begin
      WriteThreads[ii].WaitFor;
      Writeln(Format('Thread%d time is %f', [ii + 1, WriteThreads[ii].FOwnTime]));
      Writeln(Format('Thread%d number of written primes is %d', [ii + 1, WriteThreads[ii].FOwnPrimeCount]));
      WriteThreads[ii].DoTerminate;
      //Writeln(Format('Thread%d finished', [ii + 1]));
    end;

  Application.Free;
end.

