// stack-bundle: the one program of the Kubernetes VM Stack image (readystack/kubernetesvmstack). The image holds the
// stack's install bundle, its pin manifest and its operator runbook under /kubernetesvmstack, with SHA256SUMS listing
// every file; this program reads them. Standard library only, static (CGO off).
//
//	stack-bundle verify   check every file against SHA256SUMS and that no file is missing or unlisted; print
//	                      "<name> <version>: <n> files verified" and exit 0, or name each problem and exit 1
//	stack-bundle list     print SHA256SUMS
//	stack-bundle version  print "<name> <version>"
//	  -root DIR           the bundle directory (default /kubernetesvmstack)
//
// To take the bundle out of the image: docker create the image, then docker cp <container>:/kubernetesvmstack . (the
// runbook's install order starts from that directory).
package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Set at build time (-ldflags -X) from the strategy: the product name and the stack's version.
var (
	name    = "Kubernetes VM Stack"
	version = "unknown"
)

const sums = "SHA256SUMS"

func fileSum(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// readSums: path -> sha256 of SHA256SUMS (sha256sum's format: "<64 hex>  <path>").
func readSums(root string) (map[string]string, []string, error) {
	f, err := os.Open(filepath.Join(root, sums))
	if err != nil {
		return nil, nil, err
	}
	defer f.Close()
	want, order := map[string]string{}, []string{}
	sc := bufio.NewScanner(f)
	for n := 1; sc.Scan(); n++ {
		line := sc.Text()
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "  ", 2)
		if len(parts) != 2 || len(parts[0]) != 64 {
			return nil, nil, fmt.Errorf("%s line %d: not \"<sha256>  <path>\"", sums, n)
		}
		p := strings.TrimPrefix(parts[1], "./")
		if _, dup := want[p]; dup {
			return nil, nil, fmt.Errorf("%s line %d: %s listed twice", sums, n, p)
		}
		want[p] = parts[0]
		order = append(order, p)
	}
	return want, order, sc.Err()
}

func verify(root string) int {
	want, _, err := readSums(root)
	if err != nil {
		fmt.Fprintln(os.Stderr, "stack-bundle:", err)
		return 1
	}
	var problems []string
	seen := map[string]bool{}
	err = filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		rel, _ := filepath.Rel(root, p)
		rel = filepath.ToSlash(rel)
		if rel == sums {
			return nil
		}
		seen[rel] = true
		exp, ok := want[rel]
		if !ok {
			problems = append(problems, "not listed in "+sums+": "+rel)
			return nil
		}
		got, err := fileSum(p)
		if err != nil {
			return err
		}
		if got != exp {
			problems = append(problems, "sha256 differs: "+rel)
		}
		return nil
	})
	if err != nil {
		fmt.Fprintln(os.Stderr, "stack-bundle:", err)
		return 1
	}
	for p := range want {
		if !seen[p] {
			problems = append(problems, "missing: "+p)
		}
	}
	sort.Strings(problems)
	for _, p := range problems {
		fmt.Fprintln(os.Stderr, "stack-bundle:", p)
	}
	if len(problems) > 0 {
		return 1
	}
	fmt.Printf("%s %s: %d files verified\n", name, version, len(want))
	return 0
}

func main() {
	root := flag.String("root", "/kubernetesvmstack", "the bundle directory")
	flag.Usage = func() {
		fmt.Fprintln(os.Stderr, "usage: stack-bundle [-root DIR] verify|list|version")
	}
	flag.Parse()
	if flag.NArg() != 1 {
		flag.Usage()
		os.Exit(2)
	}
	switch flag.Arg(0) {
	case "verify":
		os.Exit(verify(*root))
	case "list":
		f, err := os.Open(filepath.Join(*root, sums))
		if err != nil {
			fmt.Fprintln(os.Stderr, "stack-bundle:", err)
			os.Exit(1)
		}
		defer f.Close()
		if _, err := io.Copy(os.Stdout, f); err != nil {
			os.Exit(1)
		}
	case "version":
		fmt.Printf("%s %s\n", name, version)
	default:
		flag.Usage()
		os.Exit(2)
	}
}
